# Redmine API Authentication Hardening

This branch adds personal access tokens (PATs) for Redmine REST API
authentication while keeping the existing legacy API key compatible.

## What Changed

Users can now create named personal access tokens from:

```text
My account -> Personal access tokens
```

Each PAT:

- is generated with the `redmine_pat_` prefix;
- is stored only as a SHA-256 digest;
- is displayed once after creation;
- requires an expiration date;
- is limited by the admin-configured maximum lifetime;
- can be revoked by the owner or an administrator;
- records `last_used_on`, throttled to at most once per hour.

Administrators can review and revoke tokens from:

```text
Administration -> Personal access tokens
```

The maximum PAT lifetime is configured in:

```text
Administration -> Settings -> API
```

## API Usage

PATs authenticate REST API calls through a dedicated header:

```bash
curl \
  -H "X-Redmine-Personal-Access-Token: redmine_pat_..." \
  http://localhost:3000/users/current.json
```

PATs are intentionally not accepted as the legacy `key` query parameter.
This avoids leaking new tokens through URLs, logs, browser history, and
reverse proxy access logs.

Legacy API keys still work through the existing mechanisms:

```bash
curl \
  -H "X-Redmine-API-Key: <legacy-api-key>" \
  http://localhost:3000/users/current.json
```

If both a PAT header and a legacy API key are present, the PAT header is
authoritative. An invalid PAT header returns `401 Unauthorized` instead of
falling back to the legacy key.

## Scope

This implementation intentionally does not add token scopes or rate limiting.
Those are natural follow-up hardening steps, but the current slice focuses on
token lifecycle, hashed storage, mandatory expiry, revocation, and safer API
transport.
