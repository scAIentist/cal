# cal.scaientist.eu — Hetzner deployment runbook

Self-hosted scheduling for scAIentist, a fork of [calcom/cal.diy](https://github.com/calcom/cal.diy) (MIT).
Hosting: the existing Hetzner Swarm VM (`46.225.83.45`), Postgres in the same stack, behind the existing Traefik. Deployment files and workflow: [scAIentist/traefik](https://github.com/scAIentist/traefik) → `cal/` and `docs/CAL.md`.

What this fork adds on top of upstream (keep these paths in mind when syncing the fork):

| Path | Purpose |
|---|---|
| (deployment) | lives in the infra repo [scAIentist/traefik](https://github.com/scAIentist/traefik) under `cal/` (Swarm stack, deploy workflow, backup) |
| `.github/workflows/scaientist-docker-image.yml` | builds `ghcr.io/scaientist/cal` on every push to `main` (all upstream workflows are removed, see section 9) |
| `apps/web/lib/signup/isEmailDomainAllowed.ts` + one check in `apps/web/app/api/auth/signup/route.ts` | `SIGNUP_ALLOWED_EMAIL_DOMAINS` — self-service signup only for scaientist.eu, scaientist.com, sci.tools |
| `docs/scaientist/` | this runbook and `EMAIL-MIGRATION.md` |

Facts the setup relies on:

- `scaientist.eu` mail is on **Google Workspace** (MX `smtp.google.com`). `luka@scaientist.eu` therefore already has a Google Calendar and Google Meet. Use it as the primary calendar (see section 5).
- `scaientist.com` is on Namecheap Private Email; `sci.tools` only has Namecheap email forwarding.
- DNS for `scaientist.eu` is at `cdns1/cdns2.controlpanel.si`. `cal.scaientist.eu` does not exist yet.
- The app image needs ~8 GB RAM to build, so it is built by GitHub Actions, not on the server.

---

## 1. Who does what

| Step | Owner |
|---|---|
| 2–3, 7, 9 (deploy, secrets, updates, backups) | Ivan (VM access via Dimitrije) |
| 4 (DNS record) | Luka, once Dimitrije sends the server IP |
| 5, 6, 8 (Google Cloud OAuth, Resend, first login) | Luka |

## 2–3. Server and deploy (Ivan)

Deployment moved to the infra repo: [scAIentist/traefik → docs/CAL.md](https://github.com/scAIentist/traefik/blob/main/docs/CAL.md).
In short: fill `cal/.env.example` there, store it as the `CAL_ENV` repository secret, run the "Deploy cal stack" workflow. The image is `ghcr.io/scaientist/cal:latest` (private by default: make the package public or `docker login ghcr.io` on the VM).

## 4. DNS (Luka)

At controlpanel.si for `scaientist.eu`, add `A  cal  46.225.83.45` (the Swarm VM, same as traefik.scaientist.eu). Traefik picks up the certificate automatically.

## 5. Google Calendar + Google Meet (Luka)

Do this as **luka@scaientist.eu** (Workspace), not as scaientist@gmail.com:

1. https://console.cloud.google.com → create project `scaientist-cal` inside the scaientist.eu organisation.
2. APIs & Services → Library → enable **Google Calendar API**.
3. OAuth consent screen → User type **Internal** (Workspace only, so no "unverified app" warning and no 7-day token expiry). Scopes: `.../auth/calendar.events`, `.../auth/calendar.readonly`.
4. Credentials → Create credentials → OAuth client ID → Web application. Authorized redirect URIs:
   - `https://cal.scaientist.eu/api/integrations/googlecalendar/callback`
   - `https://cal.scaientist.eu/api/auth/callback/google`
5. Download the JSON, send it to Dimitrije (or paste it yourself) as the value of `GOOGLE_API_CREDENTIALS` in `.env`, one line. Restart: `docker compose up -d`. The container seeds the credentials into the app store on start.
6. In Cal (after section 8): Apps → Calendar → **Google Calendar** → Install → pick luka@scaientist.eu. Choose the calendar to check for conflicts and the one new bookings are written to.
7. Apps → Conferencing → **Google Meet** → install, set as default location. No Daily.co key needed.
8. Until the Gmail calendar is migrated (see `EMAIL-MIGRATION.md`), also install Google Calendar a second time with scaientist@gmail.com and tick its calendar for conflict checking only. Internal OAuth apps do not accept a plain Gmail login, so for that second connection you would need an External consent screen; the simpler path is to share the Gmail calendar with luka@scaientist.eu (Calendar settings → Share with specific people, "See all event details") and tick that shared calendar inside the luka@scaientist.eu connection.

## 6. Email via Resend (Luka)

1. https://resend.com → Domains → add `scaientist.eu`. Resend gives you DKIM (3 CNAME) and an SPF/MX pair for `send.scaientist.eu`. Add them at controlpanel.si. This does not interfere with Google Workspace mail because Resend uses its own subdomain for the return path.
2. API Keys → create `cal-scaientist-eu` (sending only). Send it to Dimitrije as `EMAIL_SERVER_PASSWORD`.
3. Sender is `cal@scaientist.eu` (`EMAIL_FROM`). Change to `luka@scaientist.eu` if you prefer replies to land in your inbox; both work once the domain is verified.

Separate, unrelated finding while checking DNS: the SPF record for `scaientist.eu` is `v=spf1 a mx include:_spf.controlpanel.si ~all` and does **not** include Google. Mail sent from Workspace can land in spam. Fix at controlpanel.si: `v=spf1 include:_spf.google.com include:_spf.controlpanel.si ~all`.

## 7. Cron and backups (Ivan)

The cron sidecar is part of the Swarm stack; the nightly backup script and its crontab line are in the infra repo (`cal/backup.sh`).

## 8. First login and signup policy (Luka)

1. Open `https://cal.scaientist.eu/signup`. Email **luka@scaientist.eu**, username **luka**, strong password. Your public link is `https://cal.scaientist.eu/luka`.
2. Onboarding: timezone Europe/Ljubljana, working hours, connect Google Calendar (section 5).
3. Settings → Security → enable two-factor auth.
4. Signup stays open only for `@scaientist.eu`, `@scaientist.com` and `@sci.tools` addresses (`SIGNUP_ALLOWED_EMAIL_DOMAINS` in `.env`). Anyone else gets "Signup is restricted to company email addresses". Team invites you send from inside Cal still work for any address.
5. Optional admin role (Settings → Admin): `docker compose exec db psql -U cal -d cal -c "UPDATE \"users\" SET role='ADMIN' WHERE email='luka@scaientist.eu';"`

## 9. Updating (Ivan)

1. GitHub → scAIentist/cal → **Sync fork** (pulls upstream cal.diy into `main`). Our changes live only in the paths listed at the top, so conflicts are rare. Upstream's own CI workflows are deleted in this fork; if a sync brings some back, keep them deleted (only `scaientist-docker-image.yml` should remain).
2. The push to `main` rebuilds the image (~20 min). Then re-run "Deploy cal stack" in the infra repo, or on the VM: `docker service update --image ghcr.io/scaientist/cal:latest cal_calcom`. Migrations run on start.
3. Rollback: set `CAL_IMAGE_TAG=<previous sha>` in the `CAL_ENV` secret and redeploy.
