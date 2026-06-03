# Personal Access Tokens Design

## Context

The home task asks for a defensible slice of Redmine issue #43881, which covers
API token expiration, scopes, rate limiting, auditability, endpoint control, and
CORS. The selected slice is an ambitious but bounded Personal Access Token
(PAT) lifecycle.

This slice addresses static, long-lived API credentials by adding multiple
named PATs with mandatory expiration, hashed storage, user self-service,
admin visibility, admin revocation, and last-used tracking. Scopes and rate
limiting are explicitly deferred.

The existing legacy API key remains compatible. It is soft-deprecated in the UI
and documentation, but it continues to authenticate existing integrations.

## Goals

- Add multiple named personal access tokens per user.
- Require every PAT to expire.
- Store only a digest of each PAT, never the plaintext token.
- Show the plaintext token only once immediately after creation.
- Authenticate REST API requests with a dedicated PAT header.
- Track last use without writing to the database on every request.
- Let users list and revoke their own PATs.
- Let admins list and revoke all PATs.
- Let admins configure the maximum PAT lifetime.
- Preserve existing legacy API key behavior.

## Non-Goals

- No permission scopes in this slice.
- No API rate limiting in this slice.
- No REST API endpoints for token management.
- No automatic migration from legacy API keys to PATs.
- No hard disablement of legacy API keys.
- No shortening of existing PATs when an admin lowers the max lifetime setting.

## Data Model

Add a new `PersonalAccessToken` model and a new `personal_access_tokens` table.
The existing `Token` model is not reused because it stores plaintext token
values and already serves sessions, feeds, recovery, and legacy API keys.

Table fields:

- `id`
- `user_id`, required and indexed
- `name`, required
- `token_digest`, required, unique, indexed
- `created_on`, required
- `updated_on`, required
- `expires_on`, required
- `last_used_on`, nullable
- `revoked_on`, nullable

The plaintext token format is:

```text
redmine_pat_<random hex>
```

The digest is `SHA256(plaintext_token)`. The plaintext token is generated during
creation and is available only transiently for display after the create action.

A PAT is active when:

- it is not revoked, and
- `expires_on` is today or in the future, and
- its owner user is active.

`last_used_on` is updated after successful PAT authentication, but not more than
once per hour for the same token.

## Settings

Add a setting:

```text
personal_access_token_max_lifetime
```

Default: `90` days.

Rules:

- value must be an integer number of days;
- minimum accepted value is `1`;
- user-created PATs cannot expire later than this limit;
- the default user-facing expiration date is 30 days from today, capped by the
  admin maximum;
- reducing this setting does not mutate existing PATs.

The setting appears in the existing API settings tab alongside REST API and
JSONP settings.

## API Authentication Flow

PAT authentication applies only to REST API requests when REST API auth is
enabled and the target action accepts API auth.

`ApplicationController#find_current_user` keeps the existing flow, with PAT
resolution added before legacy API key resolution:

1. For API requests, read `X-Redmine-Personal-Access-Token`.
2. If present, resolve it through `PersonalAccessToken.find_active_by_plaintext_token`.
3. If the PAT is valid and the owner is active, authenticate as the owner.
4. Update `last_used_on` if the throttling interval has elapsed.
5. Continue to apply the existing admin switch-user behavior only if the
   resolved user is an admin.
6. If no PAT header is present, continue with the existing legacy API key, OAuth, and
   Basic auth paths.

PATs are not accepted through the legacy `key` URL parameter, the legacy
`X-Redmine-API-Key` header, or Basic auth. This is intentional: the legacy API
key remains compatible, while new PAT usage avoids URLs and username slots.

If the PAT header is present but invalid, expired, or revoked, the request does
not fall back to legacy API key, OAuth, or Basic auth credentials in the same
request. It behaves like invalid credentials and results in the existing API
unauthorized behavior.

## User UI

Add a My account page for personal access tokens:

```text
GET  /my/personal_access_tokens
POST /my/personal_access_tokens
POST /my/personal_access_tokens/:id/revoke
```

The page lists the current user's PATs:

```text
Name | Created | Expires | Last used | Status | Actions
```

Creation form:

- `name`
- `expires_on`

Validation:

- `name` is required;
- `expires_on` is required;
- expiration cannot be in the past;
- expiration cannot exceed the admin max lifetime.

After successful creation, the plaintext token is shown once on the same page in
a prominent box. It is not shown in the token list and cannot be retrieved
again.

Users can revoke only their own PATs. Revoked tokens stay visible with status
`Revoked`.

Creating and revoking PATs require sudo mode, matching the sensitivity of the
existing API key show/reset actions.

The existing My account sidebar keeps the legacy API key show/reset controls,
but adds a short warning that personal access tokens are recommended for new
integrations and links to the PAT page.

## Admin UI

Add an admin page:

```text
GET  /admin/personal_access_tokens
POST /admin/personal_access_tokens/:id/revoke
```

The page is admin-only and lists all PATs:

```text
User | Name | Created | Expires | Last used | Status | Actions
```

Admin can revoke any PAT, but cannot see plaintext token values.

The first version includes a status filter:

- active
- expired
- revoked
- all

Text search by user or token name is deferred.

Admin revocation requires sudo mode.

## Testing

Model tests for `PersonalAccessToken`:

- generates a plaintext token on create;
- stores digest, not plaintext;
- validates `user`, `name`, and `expires_on`;
- rejects past expiration;
- rejects expiration beyond admin max lifetime;
- reports active, expired, and revoked status correctly;
- finds active tokens by plaintext value;
- rejects expired and revoked tokens;
- updates `last_used_on` with one-hour throttling.

API authentication tests:

- accepts a valid PAT through `X-Redmine-Personal-Access-Token`;
- rejects expired PATs;
- rejects revoked PATs;
- rejects PATs through legacy `key` parameter;
- keeps legacy API key authentication working.

User UI tests:

- user can create a PAT and sees plaintext once;
- user can list own PATs;
- user can revoke own PAT;
- user cannot revoke another user's PAT.

Admin UI tests:

- admin can list all PATs;
- admin can filter active, expired, revoked, and all tokens;
- admin can revoke any PAT;
- non-admin cannot access the admin PAT page.

## Documentation

Update the task README or equivalent delivery notes with:

- chosen slice and rationale;
- what is implemented;
- what is deferred;
- assumptions;
- setup and verification commands;
- AI workflow notes, including environment findings.

Deferred items must explicitly mention scopes and rate limiting so the reviewer
can see that they were considered and intentionally excluded from this slice.

## Trade-Offs

This design is more ambitious than simply expiring the existing API key, but it
is still bounded. It avoids the highest-risk parts of the original ticket:
permission scopes and rate limiting. It also preserves backward compatibility by
leaving the legacy API key path working.

Using a separate table is more code than extending `Token`, but it keeps hashed
PATs separate from Redmine's existing plaintext token uses and avoids changing
session/feed/recovery behavior.

Using a new PAT-specific header is less compatible than accepting PATs through
the existing API key locations, but it prevents new tokens from being passed in
URLs and keeps legacy and PAT behavior easy to reason about.
