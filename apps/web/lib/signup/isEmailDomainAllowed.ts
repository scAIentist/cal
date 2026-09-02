/**
 * Optional signup restriction for self-hosted instances.
 *
 * Set `SIGNUP_ALLOWED_EMAIL_DOMAINS="example.com,example.org"` to only allow
 * self-service signups from those email domains. Leave it unset or empty to
 * keep upstream behaviour (any domain). Team-invite signups (with a token)
 * are not affected by this check.
 */
export function getAllowedSignupDomains(raw: string | undefined = process.env.SIGNUP_ALLOWED_EMAIL_DOMAINS): string[] {
  return (raw ?? "")
    .split(",")
    .map((domain) => domain.trim().toLowerCase().replace(/^@/, ""))
    .filter(Boolean);
}

export function isEmailDomainAllowed(email: string, allowedDomains: string[] = getAllowedSignupDomains()): boolean {
  if (allowedDomains.length === 0) return true;
  const at = email.lastIndexOf("@");
  if (at === -1) return false;
  const domain = email.slice(at + 1).trim().toLowerCase();
  return allowedDomains.includes(domain);
}
