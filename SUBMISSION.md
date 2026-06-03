# Submission Notes: Strengthening Redmine API Authentication

## Scope

This branch is based on Redmine `6.1.2` and implements a focused slice of Redmine issue `#43881`, which asks for API authentication hardening through token expiration, scopes, and rate limiting.

Rather than attempting a shallow version of all three pillars, I chose to ship a complete Personal Access Token lifecycle slice: mandatory expiration, hashed storage, revocation, one-time plaintext display, administrator visibility, and a dedicated REST API authentication header.

This is intentionally additive. Existing Redmine API keys continue to work, including the legacy `?key=<api_key>` style.

## What Shipped

- Added `PersonalAccessToken` model and migration.
- Stores only SHA-256 token digests; plaintext is shown once.
- Requires expiration and validates it against an admin-configured maximum lifetime.
- Authenticates REST API requests via `X-Redmine-Personal-Access-Token`.
- Rejects PATs passed through `?key=...`.
- Keeps legacy API key authentication working.
- Prevents invalid PAT headers from falling back to legacy keys.
- Tracks `last_used_on`, throttled to at most once per hour.
- Adds user UI for creating, listing, and revoking tokens.
- Adds admin UI for listing, filtering, and revoking tokens.
- Adds API settings field for maximum PAT lifetime.
- Adds English and Russian locale strings.
- Adds documentation and AI workflow notes.

## Compatibility and Trade-offs

Legacy API keys remain supported through existing Redmine mechanisms:

```text
/users/current.json?key=<legacy_api_key>
X-Redmine-API-Key: <legacy_api_key>
```

New PATs are accepted only through the dedicated header:

```text
X-Redmine-Personal-Access-Token: redmine_pat_...
```

This avoids putting new long-lived credentials into URLs, while preserving compatibility for existing integrations.

If both a PAT header and a legacy key are supplied, the PAT header is authoritative. An invalid PAT returns `401` rather than falling back to the legacy key, keeping authentication behavior explicit.

Deferred work:

- **Scopes**: valuable, but require a permissions model, UI choices, defaults, and compatibility rules.
- **Rate limiting**: important, but Redmine does not expose a small existing abstraction for it; adding one hastily would be risky.
- **API key migration**: existing keys remain supported; forced migration needs product guidance.
- **Richer audit logs**: deferred beyond `last_used_on`.

## How to Run

```bash
BUNDLE_USER_HOME=.bundle/home \
PATH=/opt/homebrew/opt/ruby@3.3/bin:/opt/homebrew/lib/ruby/gems/3.3.0/bin:$PATH \
bundle exec rake db:migrate
```

```bash
BUNDLE_USER_HOME=.bundle/home \
PATH=/opt/homebrew/opt/ruby@3.3/bin:/opt/homebrew/lib/ruby/gems/3.3.0/bin:$PATH \
bundle exec rails server -b 127.0.0.1 -p 3001
```

Enable REST API in:

```text
Administration -> Settings -> API
```

User token management:

```text
My account -> Personal access tokens
```

Admin token management:

```text
Administration -> Personal access tokens
```

## Verification

Full Rails suite:

```text
5506 runs
24842 assertions
0 failures
0 errors
44 skips
```

The skips were due to optional external test dependencies such as repository fixtures, LDAP, ImageMagick, and GhostScript.

Manual REST API checks confirmed:

- valid PAT header returns `HTTP 200`;
- PAT in `?key=` returns `HTTP 401`;
- revoked PAT returns `HTTP 401`;
- legacy API key in `?key=` still returns `HTTP 200`;
- invalid PAT plus valid legacy key returns `HTTP 401`;
- `GET`, `POST`, `PUT`, and `DELETE` work through PAT authentication.

Playwright checks covered:

- user PAT creation;
- one-time plaintext display;
- user revoke flow;
- admin list/filter/revoke flow;
- API settings maximum lifetime field;
- Russian locale rendering.

Detailed verification commands are included in `README-taxdome-api-auth.md`.

## AI Workflow

Codex was used as the primary coding assistant. The work was directed through repository inspection, scoping, design, implementation planning, test-first vertical slices, manual verification, and final review.

Workflow artifacts:

```text
docs/ai-session-excerpts.md
docs/ai-workflow.md
docs/superpowers/specs/2026-06-03-personal-access-tokens-design.md
docs/superpowers/plans/2026-06-03-personal-access-tokens-implementation.md
```

The session excerpts capture several points where the AI-assisted workflow was corrected or narrowed, including the PAT slice selection, the decision not to accept PATs through `?key=...`, the no-fallback authentication rule, the Ruby/test environment adjustments, and the later Russian localization pass.

The commits are intentionally split by vertical slice: design, planning, model, REST authentication, user UI, admin controls, documentation, localization, and submission summary.

## Rubric Mapping

- **Scoping judgment**: shipped one coherent PAT lifecycle slice instead of a partial implementation of expiration, scopes, and rate limiting.
- **AI workflow quality**: included workflow artifacts, planning docs, and atomic commits showing iterative refinement.
- **Codebase fit**: used Redmine models, controllers, settings, routes, locales, and test patterns.
- **Working software**: automated tests, full suite, curl checks, and Playwright checks pass.
- **Communication**: trade-offs and deferred work are explicitly documented.
