# AI Session Excerpts

This file summarizes concrete moments from the AI-assisted workflow. It is not a full transcript dump; instead, it captures the decisions, corrections, and verification loops that shaped the final slice.

## 1. Scoping the Ticket

**Prompt / direction**

After reading the assignment and Redmine issue `#43881`, I asked Codex to help compare possible implementation slices rather than rushing into code.

**AI output**

Codex initially explored several possible slices, including token expiration, token scopes, rate limiting, and a broader personal access token implementation.

**Human decision**

I selected the ambitious Personal Access Token lifecycle slice, while explicitly deferring scopes and rate limiting. The reasoning was that expiration, hashed storage, revocation, and a safer transport mechanism formed a coherent feature, whereas trying to implement all three original pillars would likely produce a shallow or unfinished result.

**Result**

The final branch ships a complete PAT lifecycle slice and documents the deferred work clearly.

## 2. Choosing a Dedicated PAT Header

**Prompt / direction**

I asked Codex to plan how new tokens should authenticate REST API calls without breaking legacy integrations.

**AI output**

The design considered accepting tokens through existing API key mechanisms, including query parameters.

**Human correction**

I rejected accepting PATs through `?key=...`, because a new credential type should not inherit the least safe legacy transport path. At the same time, I required old API keys to keep working through `?key=...` for compatibility.

**Result**

PATs authenticate only through:

```text
X-Redmine-Personal-Access-Token
```

Legacy API keys still work through existing Redmine mechanisms.

## 3. Avoiding Ambiguous Fallback

**Prompt / direction**

During API authentication design, I asked Codex to make the precedence rules explicit.

**AI output**

The initial shape could have allowed an invalid PAT header to be ignored, letting a valid legacy API key authenticate the same request.

**Human correction**

I required the PAT header to be authoritative. If a client sends a PAT header, Redmine should evaluate that credential rather than silently falling back to another one.

**Result**

An invalid PAT plus a valid legacy API key returns `401`. This behavior is covered by integration tests and manual `curl` verification.

## 4. Ruby Environment and Test Discipline

**Prompt / direction**

I asked Codex to install the correct Ruby version and verify the project before implementation.

**AI output**

Codex installed Ruby through Homebrew, then found that the default RubyGems version was incompatible with the Redmine dependency set.

**Human / workflow correction**

The environment was adjusted to use Ruby `3.3`, RubyGems `3.6.9`, and Bundler `2.6.9`. Later, when Rails tests produced SQLite locking under parallel execution, I directed the workflow toward sequential test runs.

**Result**

The implementation was verified with focused tests and the full Rails test suite using a stable local environment.

## 5. Localization Gap

**Prompt / direction**

After implementation, I asked Codex to review whether anything was missing or contradictory.

**AI output**

Codex identified that the new UI strings existed in `en.yml` but not in `ru.yml`.

**Human decision**

I asked for Russian locale coverage as a small separate commit, rather than leaving a mixed-language UI in the local verification environment.

**Result**

Russian translations were added in:

```text
c43671ace Add Russian personal access token translations
```

The user and admin PAT flows were then rechecked through Playwright in Russian.

## 6. Verification Beyond Tests

**Prompt / direction**

I asked Codex to verify the feature not only with tests, but also through direct REST API requests and browser automation.

**AI output**

Codex ran focused tests, the full Rails suite, `curl` commands, and Playwright UI flows.

**Human correction**

When one `curl` command failed because `zsh` interpreted an unquoted `?` in the URL as a glob, I narrowed the issue to shell quoting rather than API behavior and reran the request correctly.

**Result**

Manual REST checks confirmed:

- PAT header authentication works.
- PATs are rejected in `?key=...`.
- legacy API keys still work in `?key=...`.
- revoked PATs are rejected.
- invalid PATs do not fall back to legacy keys.
- `GET`, `POST`, `PUT`, and `DELETE` work through PAT authentication.

## Related Artifacts

The structured design and implementation artifacts are:

- `docs/superpowers/specs/2026-06-03-personal-access-tokens-design.md`
- `docs/superpowers/plans/2026-06-03-personal-access-tokens-implementation.md`
- `docs/ai-workflow.md`
