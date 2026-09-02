# Moving Luka to luka@scaientist.eu

Goal: `luka@scaientist.eu` becomes the identity everywhere, while `lr@scaientist.com` and `scaientist@gmail.com` keep working until they can be retired. Nothing here is Cal-specific except step 1.

## Where each address lives

| Address | Provider | Role after migration |
|---|---|---|
| luka@scaientist.eu | Google Workspace (scaientist.eu MX is `smtp.google.com`) | primary mail, primary calendar, Cal login |
| lr@scaientist.com | Namecheap Private Email | receive-only, auto-forwarded to luka@scaientist.eu |
| scaientist@gmail.com | consumer Google account | old calendar until events are moved; then only for whatever Google services are still tied to it |

## Steps

1. **Cal**: sign up with luka@scaientist.eu (runbook section 8). Do not create a second account for the other addresses.
2. **Forward lr@scaientist.com → luka@scaientist.eu**: log in at https://privateemail.com as lr@scaientist.com → Settings → Mail → Auto forward → forward to luka@scaientist.eu, keep a copy. Do the same in Gmail settings for scaientist@gmail.com (Settings → Forwarding and POP/IMAP → Add forwarding address) so both old inboxes end up in one place.
3. **Send as the old addresses from Workspace** (so replies to old threads still come from the address people know): Gmail (Workspace) → Settings → Accounts → "Send mail as" → add lr@scaientist.com with Private Email SMTP (`mail.privateemail.com`, port 465, SSL). Default "reply from the same address the message was sent to". Set luka@scaientist.eu as the default sender.
4. **Calendar**: in scaientist@gmail.com → Calendar settings → Export, then Import into luka@scaientist.eu. Existing recurring meetings you organised keep their Meet links only if you re-share them; for the next 2–3 weeks keep the Gmail calendar shared with luka@scaientist.eu ("See all event details") so Cal can still see conflicts.
5. **Signature, LinkedIn, Calendly links, website contact**: replace with luka@scaientist.eu and `https://cal.scaientist.eu/luka`.
6. **Retire**: when the forward from lr@scaientist.com has been quiet for a month, decide whether to keep the Private Email mailbox (cost) or convert scaientist.com to plain forwarding at Namecheap (free, like sci.tools).

## Two DNS fixes to do while you are in controlpanel.si

- SPF for scaientist.eu currently omits Google: change to `v=spf1 include:_spf.google.com include:_spf.controlpanel.si ~all`.
- Add DKIM for Workspace if not present (Google Admin → Apps → Google Workspace → Gmail → Authenticate email → generate record).
