# cal.scaientist.eu — Hetzner deployment runbook

Self-hosted scheduling for scAIentist, a fork of [calcom/cal.diy](https://github.com/calcom/cal.diy) (MIT).
Hosting: one Hetzner VM with Docker Compose, Postgres on the same box, behind the existing Traefik.

What this fork adds on top of upstream (keep these paths in mind when syncing the fork):

| Path | Purpose |
|---|---|
| `deploy/hetzner/` | `docker-compose.yml`, `.env.example`, `cron.sh` (replaces Vercel Cron), `backup.sh` |
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
| 1–3, 7, 9 (server, compose, secrets, updates, backups) | Dimitrije |
| 4 (DNS record) | Luka, once Dimitrije sends the server IP |
| 5, 6, 8 (Google Cloud OAuth, Resend, first login) | Luka |

## 2. Server (Dimitrije)

1. Hetzner Cloud **CX22** (2 vCPU / 4 GB / 40 GB, Falkenstein or Nuremberg) is enough for one user. Ubuntu 24.04, Docker + Compose plugin, the existing Traefik stack with a network named `traefik` and a Let's Encrypt resolver named `letsencrypt` (change the two names in `deploy/hetzner/docker-compose.yml` if yours differ).
2. Firewall: only 22/80/443 inbound. Port 3000 is never published; Traefik reaches the container over the Docker network.
3. Send Luka the server's public IPv4 (and IPv6 if enabled) so the DNS record can be created.

## 3. Deploy (Dimitrije)

```sh
sudo mkdir -p /opt/cal && sudo chown $USER /opt/cal
git clone https://github.com/scAIentist/cal /opt/cal
cd /opt/cal/deploy/hetzner
cp .env.example .env
```

Fill `.env`:

```sh
openssl rand -hex 24      # POSTGRES_PASSWORD (letters/digits only, it goes into a URL)
openssl rand -base64 32   # NEXTAUTH_SECRET
openssl rand -base64 24   # CALENDSO_ENCRYPTION_KEY (must be exactly 32 bytes)
openssl rand -hex 16      # CRON_API_KEY
openssl rand -hex 32      # CRON_SECRET
```

Leave `GOOGLE_API_CREDENTIALS` and `EMAIL_SERVER_PASSWORD` empty until Luka sends them (sections 5 and 6), then fill and `docker compose up -d` again.

Pull the image and start:

```sh
docker login ghcr.io          # only if the package is private: GitHub username + a PAT with read:packages
docker compose pull
docker compose up -d
docker compose logs -f calcom  # first start runs migrations and seeds the app store, takes ~1 minute
```

The image is `ghcr.io/scaientist/cal:latest`, built by the workflow on every push to `main`. If the first `docker compose pull` is denied, make the package public: GitHub → scAIentist → Packages → cal → Package settings → Change visibility.

Check: `curl -I https://cal.scaientist.eu` returns 200 once DNS (section 4) has propagated and Traefik has issued the certificate.

## 4. DNS (Luka)

At controlpanel.si for `scaientist.eu`, add:

```
A     cal   <server IPv4>
AAAA  cal   <server IPv6>   (only if the server has one and Traefik listens on it)
```

Tell Dimitrije when it is done; Traefik picks up the certificate automatically.

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

## 7. Cron and backups (Dimitrije)

- Reminders, webhooks and calendar sync are driven by the `cron` sidecar in the compose file; nothing to install. Check with `docker compose logs cron`.
- Nightly database dump: `crontab -e` → `15 3 * * * /opt/cal/deploy/hetzner/backup.sh >> /opt/cal/backups/backup.log 2>&1`. Keeps 14 days in `/opt/cal/backups`. Copy them off-box (Hetzner Storage Box or S3) if you want real disaster recovery.

## 8. First login and signup policy (Luka)

1. Open `https://cal.scaientist.eu/signup`. Email **luka@scaientist.eu**, username **luka**, strong password. Your public link is `https://cal.scaientist.eu/luka`.
2. Onboarding: timezone Europe/Ljubljana, working hours, connect Google Calendar (section 5).
3. Settings → Security → enable two-factor auth.
4. Signup stays open only for `@scaientist.eu`, `@scaientist.com` and `@sci.tools` addresses (`SIGNUP_ALLOWED_EMAIL_DOMAINS` in `.env`). Anyone else gets "Signup is restricted to company email addresses". Team invites you send from inside Cal still work for any address.
5. Optional admin role (Settings → Admin): `docker compose exec db psql -U cal -d cal -c "UPDATE \"users\" SET role='ADMIN' WHERE email='luka@scaientist.eu';"`

## 9. Updating (Dimitrije)

1. GitHub → scAIentist/cal → **Sync fork** (pulls upstream cal.diy into `main`). Our changes live only in the paths listed at the top, so conflicts are rare.
   Upstream's own CI workflows (`.github/workflows/*`, ~50 files) are deleted in this fork because they need Cal.com's secrets and fail on every push. If a sync brings some back or reports a conflict on them, resolve by keeping them deleted (or click "Disable workflow" in the Actions tab for any that reappear). Only `scaientist-docker-image.yml` should remain.
2. The push to `main` triggers the image build (~20–30 min). Watch Actions.
3. On the server: `cd /opt/cal/deploy/hetzner && docker compose pull && docker compose up -d`. Migrations run on start.
4. Rollback: set `CAL_IMAGE_TAG=<previous sha>` in `.env` and `docker compose up -d`.
