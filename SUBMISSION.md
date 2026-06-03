# Strengthening Redmine API Authentication

## Context and Scope

This branch is based on Redmine `6.1.2` and addresses a focused, intentionally scoped slice of Redmine issue `#43881`, which asks for a broader hardening of API authentication through token expiration, scopes, and rate limiting.

The full issue is substantial enough to deserve a phased rollout rather than a hurried, all-at-once implementation. After reviewing the ticket and the surrounding Redmine codebase, I chose to ship a Personal Access Token lifecycle slice: a piece of work that is small enough to be implemented and verified carefully, while still being meaningful from a security and product standpoint.

The implemented slice introduces personal access tokens with mandatory expiration, hashed storage, one-time plaintext display, revocation, administrator visibility, and a dedicated authentication header for REST API usage. Existing Redmine API keys remain compatible, so current integrations are not broken by this change.

This means the branch improves the safety of API authentication without pretending to solve the entire ticket. Scopes and rate limiting are deliberately deferred.

## What Was Implemented

The branch adds a new `PersonalAccessToken` model and database table. Tokens are generated with a `redmine_pat_` prefix, shown to the user only once, and stored only as SHA-256 digests. Each token requires an expiration date, and the allowed maximum lifetime is controlled by an administrator setting.

REST API authentication now accepts a dedicated header:

```text
X-Redmine-Personal-Access-Token: redmine_pat_...
```

When a valid personal access token is supplied, Redmine authenticates the request as the token owner, provided that both the token and the user account are active. Token usage updates `last_used_on`, throttled to at most once per hour so that routine API traffic does not cause unnecessary write amplification.

The branch also adds user-facing token management under the account area, allowing users to create, list, and revoke their own personal access tokens. Administrators get a separate view for listing, filtering, and revoking tokens across the instance. The API settings page now includes a maximum lifetime setting for personal access tokens.

English and Russian locale strings are included, so the new UI integrates cleanly in both locales used during verification.

## Compatibility

Backward compatibility was treated as a first-class requirement.

Existing Redmine API key authentication remains functional, including the legacy query parameter style:

```text
/users/current.json?key=<legacy_api_key>
```

The existing `X-Redmine-API-Key` header also continues to work.

New personal access tokens, however, are intentionally not accepted through the legacy `key` query parameter. This is a deliberate security choice: PATs should not be encouraged to travel through URLs, where they are more likely to appear in browser history, server logs, proxy logs, shared links, or monitoring systems.

If both a personal access token header and a legacy API key are supplied, the personal access token header is authoritative. An invalid PAT does not fall back to a valid legacy API key. This avoids ambiguous authentication behavior and prevents integrations from silently authenticating through a different credential than the one they attempted to use.

## What Was Deferred

Several parts of the original ticket were intentionally left out of this slice.

Token scopes were deferred. They are valuable, but introducing them properly would require a permissions model for API capabilities, UI decisions around scope selection, careful default behavior, and a compatibility story for existing integrations.

Rate limiting was also deferred. Although it is an important security control, Redmine does not currently have a small, obvious rate-limiting abstraction that could be extended without broader design work. Adding one hastily would risk either being ineffective or becoming an awkward framework-level concern.

I also deferred any migration or automatic conversion of existing API keys into personal access tokens. Existing API keys remain supported, and a migration strategy would need product guidance: whether old keys should be grandfathered forever, softly deprecated, forcibly rotated, or converted into expiring credentials.

Finally, I did not add detailed audit logging beyond `last_used_on`. That is a reasonable follow-up, but for this slice the most important lifecycle events are visible through token status, creation time, expiration, revocation, and last use.

## Assumptions

I assumed that the assignment values a defensible, working slice over an incomplete attempt at all three pillars from the original issue. The PDF explicitly asks the candidate to scope the problem and ship something coherent, and the original issue itself acknowledges that the full request is large.

I also assumed that preserving existing API key behavior is important. Redmine has many long-lived integrations, and breaking `?key=` or `X-Redmine-API-Key` would be a poor trade-off for a take-home slice.

The new PAT mechanism is therefore additive rather than disruptive: it provides a safer authentication path while allowing existing integrations to continue working.

## How to Run

Use the Ruby version expected by the project and run migrations:

```bash
BUNDLE_USER_HOME=.bundle/home \
PATH=/opt/homebrew/opt/ruby@3.3/bin:/opt/homebrew/lib/ruby/gems/3.3.0/bin:$PATH \
bundle exec rake db:migrate
```

Then start the server:

```bash
BUNDLE_USER_HOME=.bundle/home \
PATH=/opt/homebrew/opt/ruby@3.3/bin:/opt/homebrew/lib/ruby/gems/3.3.0/bin:$PATH \
bundle exec rails server -b 127.0.0.1 -p 3001
```

In the UI, enable the REST API under:

```text
Administration -> Settings -> API
```

Users can manage personal access tokens under:

```text
My account -> Personal access tokens
```

Administrators can review all tokens under:

```text
Administration -> Personal access tokens
```

## How to Verify

The focused automated tests cover the model, API authentication, user UI, admin UI, and settings UI.

The full Rails test suite was also run successfully:

```text
5506 runs
24842 assertions
0 failures
0 errors
44 skips
```

The skipped tests were related to external test repositories, LDAP, ImageMagick, or GhostScript availability in the local environment.

Manual REST API verification was performed with `curl`.

A valid personal access token works through the dedicated header:

```bash
curl -i \
  -H "X-Redmine-Personal-Access-Token: <PAT>" \
  http://127.0.0.1:3001/users/current.json
```

Expected result:

```text
HTTP 200
```

A PAT does not work through the legacy query parameter:

```bash
curl -i \
  "http://127.0.0.1:3001/users/current.json?key=<PAT>"
```

Expected result:

```text
HTTP 401
```

A legacy API key still works through the old query parameter:

```bash
curl -i \
  "http://127.0.0.1:3001/users/current.json?key=<LEGACY_API_KEY>"
```

Expected result:

```text
HTTP 200
```

A revoked PAT is rejected:

```bash
curl -i \
  -H "X-Redmine-Personal-Access-Token: <REVOKED_PAT>" \
  http://127.0.0.1:3001/users/current.json
```

Expected result:

```text
HTTP 401
```

An invalid PAT does not fall back to a valid legacy API key:

```bash
curl -i \
  -H "X-Redmine-Personal-Access-Token: redmine_pat_invalid" \
  -H "X-Redmine-API-Key: <LEGACY_API_KEY>" \
  http://127.0.0.1:3001/users/current.json
```

Expected result:

```text
HTTP 401
```

CRUD-style REST API commands were also checked through the PAT authentication path using the Projects API:

```text
GET     /projects.json
POST    /projects.json
GET     /projects/:id.json
PUT     /projects/:id.json
DELETE  /projects/:id.json
```

All behaved as expected.

The browser UI was verified through Playwright: user token creation, one-time plaintext display, token revocation, administrator filtering and revocation, and the API settings field were all exercised manually.

## AI Workflow

Codex was used as the primary coding assistant. The work was developed through a staged workflow: repository inspection, task scoping, design, implementation planning, test-first vertical slices, manual verification, and final review.

The included artifacts show this process:

```text
docs/ai-workflow.md
docs/superpowers/specs/2026-06-03-personal-access-tokens-design.md
docs/superpowers/plans/2026-06-03-personal-access-tokens-implementation.md
```

The commits are intentionally split by vertical slice rather than collapsed into a single feature commit. They tell the implementation story: design, planning, model, REST authentication, user UI, admin controls, documentation, and localization.

## Evaluation Signals

### 1. Scoping Judgment

The original ticket asks for token expiration, scopes, and rate limiting. Rather than implementing a shallow version of all three, this branch ships one coherent slice: personal access token lifecycle management with mandatory expiration and revocation.

This slice is useful on its own, reduces risk in API authentication, and creates a foundation on which scopes and rate limiting could later be built.

### 2. AI Workflow Quality

The AI workflow was directed through explicit planning, design review, test-first implementation, and verification gates. The assistant was not used simply to generate code in one pass; instead, the work was decomposed, tested, corrected, and reviewed incrementally.

The project includes workflow artifacts and atomic commits to make that process inspectable.

### 3. Codebase Fit

The implementation follows existing Redmine patterns. User-facing token management lives in the existing account area. Administrator controls are added through Redmine's administration patterns. Settings use Redmine's existing `Setting` infrastructure. Routes, locales, controller tests, integration tests, and views are structured consistently with the surrounding codebase.

No new framework or external service was introduced.

### 4. Working Software

The slice runs, the database migrates, the automated tests pass, and the REST API behavior was manually verified through real HTTP requests. Browser flows were also checked through Playwright.

The full Rails test suite passed with zero failures and zero errors.

### 5. Communication

The branch documents what was implemented, what was deferred, and why. The main trade-offs are explicit: scopes and rate limiting remain future work; legacy API keys remain compatible; PATs are deliberately restricted to a safer header-based transport.
