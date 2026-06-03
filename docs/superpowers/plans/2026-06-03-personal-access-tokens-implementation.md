# Personal Access Tokens Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build a bounded Personal Access Token lifecycle for Redmine REST API authentication.

**Architecture:** Add a separate `PersonalAccessToken` model/table with hashed storage and mandatory expiration. Authenticate REST requests through `X-Redmine-Personal-Access-Token` before legacy API keys while preserving legacy behavior. Add user and admin UI for create/list/revoke plus admin max-lifetime setting.

**Tech Stack:** Ruby 3.3, Rails 7.2, Redmine controller/view/test patterns, Minitest, SQLite locally.

---

## File Map

- Create `db/migrate/20260603090000_create_personal_access_tokens.rb`: PAT table and indexes.
- Create `app/models/personal_access_token.rb`: token generation, digest lookup, expiration, revocation, last-used throttling.
- Modify `app/models/user.rb`: `has_many :personal_access_tokens`.
- Modify `config/settings.yml`: `personal_access_token_max_lifetime`.
- Modify `app/controllers/application_controller.rb`: PAT API auth resolver.
- Create `app/controllers/my/personal_access_tokens_controller.rb`: self-service PAT UI.
- Create `app/views/my/personal_access_tokens/index.html.erb`: list/create/revoke UI.
- Modify `app/views/my/_sidebar.html.erb`: soft-deprecate legacy API key and link PAT page.
- Create `app/controllers/admin/personal_access_tokens_controller.rb`: admin list/revoke.
- Create `app/views/admin/personal_access_tokens/index.html.erb`: admin token index.
- Modify `app/views/settings/_api.html.erb`: max lifetime setting.
- Modify `lib/redmine/preparation.rb`: admin menu entry.
- Modify `config/routes.rb`: user/admin PAT routes.
- Modify `config/locales/en.yml`: labels, notices, validation messages.
- Create `test/unit/personal_access_token_test.rb`: model behavior.
- Modify `test/integration/api_test/authentication_test.rb`: API auth behavior.
- Create `test/functional/my/personal_access_tokens_controller_test.rb`: user UI behavior.
- Create `test/functional/admin/personal_access_tokens_controller_test.rb`: admin UI behavior.
- Modify `test/functional/settings_controller_test.rb`: setting rendered/saved.
- Create `README-taxdome-api-auth.md`: delivery notes and verification.
- Create `docs/ai-workflow.md`: concise AI workflow artifact.

## Task 1: Model, Migration, Setting

**Files:**
- Create: `db/migrate/20260603090000_create_personal_access_tokens.rb`
- Create: `app/models/personal_access_token.rb`
- Modify: `app/models/user.rb`
- Modify: `config/settings.yml`
- Create: `test/unit/personal_access_token_test.rb`

- [ ] **Step 1: Write failing model tests**

Add tests for plaintext-once generation, digest storage, active lookup, expiration, revocation, max lifetime validation, and last-used throttling.

- [ ] **Step 2: Verify model tests fail**

Run: `BUNDLE_USER_HOME=.bundle/home PATH=/opt/homebrew/opt/ruby@3.3/bin:/opt/homebrew/lib/ruby/gems/3.3.0/bin:$PATH bundle exec ruby test/unit/personal_access_token_test.rb`

Expected: failure because `PersonalAccessToken` is not defined.

- [ ] **Step 3: Add migration/model/user association/setting**

Implement `PersonalAccessToken` with:

```ruby
TOKEN_PREFIX = 'redmine_pat_'
LAST_USED_UPDATE_INTERVAL = 1.hour
attr_reader :plain_value
```

Generate `plain_value`, store `Digest::SHA256.hexdigest(plain_value)`, validate mandatory expiration and admin max lifetime, and expose `find_active_by_plaintext_token`.

- [ ] **Step 4: Run migration and model tests**

Run development and test migrations, then rerun `test/unit/personal_access_token_test.rb`.

- [ ] **Step 5: Commit vertical slice**

Commit message: `Add personal access token model`

## Task 2: REST API Authentication

**Files:**
- Modify: `app/controllers/application_controller.rb`
- Modify: `test/integration/api_test/authentication_test.rb`

- [ ] **Step 1: Write failing API auth tests**

Add tests for valid PAT header, expired PAT rejection, revoked PAT rejection, PAT not accepted via `key=`, invalid PAT header not falling back to legacy key, and legacy key still working.

- [ ] **Step 2: Verify API auth tests fail**

Run: `BUNDLE_USER_HOME=.bundle/home PATH=/opt/homebrew/opt/ruby@3.3/bin:/opt/homebrew/lib/ruby/gems/3.3.0/bin:$PATH bundle exec ruby test/integration/api_test/authentication_test.rb`

Expected: new PAT tests fail because the header is ignored.

- [ ] **Step 3: Implement PAT resolver in `ApplicationController#find_current_user`**

Read `X-Redmine-Personal-Access-Token`; if present, authenticate only through PAT and do not fall back to other auth methods when invalid.

- [ ] **Step 4: Verify API auth tests pass**

Rerun `test/integration/api_test/authentication_test.rb` and `test/unit/personal_access_token_test.rb`.

- [ ] **Step 5: Commit vertical slice**

Commit message: `Authenticate API requests with personal access tokens`

## Task 3: User PAT UI

**Files:**
- Create: `app/controllers/my/personal_access_tokens_controller.rb`
- Create: `app/views/my/personal_access_tokens/index.html.erb`
- Modify: `app/views/my/_sidebar.html.erb`
- Modify: `config/routes.rb`
- Modify: `config/locales/en.yml`
- Create: `test/functional/my/personal_access_tokens_controller_test.rb`

- [ ] **Step 1: Write failing user UI tests**

Cover index, create with one-time plaintext display, validation failure, own revoke, and rejecting another user's token.

- [ ] **Step 2: Verify user UI tests fail**

Run: `BUNDLE_USER_HOME=.bundle/home PATH=/opt/homebrew/opt/ruby@3.3/bin:/opt/homebrew/lib/ruby/gems/3.3.0/bin:$PATH bundle exec ruby test/functional/my/personal_access_tokens_controller_test.rb`

Expected: routing/controller missing.

- [ ] **Step 3: Implement user controller/routes/view/sidebar/locales**

Use `require_login`, `require_sudo_mode :create, :revoke`, and the existing My account layout/sidebar pattern.

- [ ] **Step 4: Verify user UI tests pass**

Run the new functional test plus `test/functional/my_controller_test.rb`.

- [ ] **Step 5: Commit vertical slice**

Commit message: `Add personal access token self-service UI`

## Task 4: Admin Governance and Settings

**Files:**
- Create: `app/controllers/admin/personal_access_tokens_controller.rb`
- Create: `app/views/admin/personal_access_tokens/index.html.erb`
- Modify: `app/views/settings/_api.html.erb`
- Modify: `lib/redmine/preparation.rb`
- Modify: `config/routes.rb`
- Modify: `config/locales/en.yml`
- Create: `test/functional/admin/personal_access_tokens_controller_test.rb`
- Modify: `test/functional/settings_controller_test.rb`

- [ ] **Step 1: Write failing admin/settings tests**

Cover admin list, status filters, admin revoke, non-admin denial, and max lifetime setting rendering/saving.

- [ ] **Step 2: Verify admin/settings tests fail**

Run admin PAT test and settings controller test selection.

- [ ] **Step 3: Implement admin controller/routes/view/menu/settings/locales**

Use `require_admin`, `require_sudo_mode :revoke`, admin layout, and API settings tab.

- [ ] **Step 4: Verify admin/settings tests pass**

Run admin PAT test, settings controller test, user UI test, and API auth test.

- [ ] **Step 5: Commit vertical slice**

Commit message: `Add admin governance for personal access tokens`

## Task 5: Delivery Docs and Full Verification

**Files:**
- Create: `README-taxdome-api-auth.md`
- Create: `docs/ai-workflow.md`

- [ ] **Step 1: Write delivery docs**

Document approach, done/deferred work, assumptions, setup, verification commands, and AI workflow notes.

- [ ] **Step 2: Run automated tests**

Run:

```bash
BUNDLE_USER_HOME=.bundle/home PATH=/opt/homebrew/opt/ruby@3.3/bin:/opt/homebrew/lib/ruby/gems/3.3.0/bin:$PATH bundle exec ruby test/unit/personal_access_token_test.rb
BUNDLE_USER_HOME=.bundle/home PATH=/opt/homebrew/opt/ruby@3.3/bin:/opt/homebrew/lib/ruby/gems/3.3.0/bin:$PATH bundle exec ruby test/integration/api_test/authentication_test.rb
BUNDLE_USER_HOME=.bundle/home PATH=/opt/homebrew/opt/ruby@3.3/bin:/opt/homebrew/lib/ruby/gems/3.3.0/bin:$PATH bundle exec ruby test/functional/my/personal_access_tokens_controller_test.rb
BUNDLE_USER_HOME=.bundle/home PATH=/opt/homebrew/opt/ruby@3.3/bin:/opt/homebrew/lib/ruby/gems/3.3.0/bin:$PATH bundle exec ruby test/functional/admin/personal_access_tokens_controller_test.rb
BUNDLE_USER_HOME=.bundle/home PATH=/opt/homebrew/opt/ruby@3.3/bin:/opt/homebrew/lib/ruby/gems/3.3.0/bin:$PATH bundle exec ruby test/functional/settings_controller_test.rb
```

- [ ] **Step 3: Verify direct REST API behavior**

Start Rails locally, create a PAT through Rails runner or UI, then verify:

```bash
curl -fsS -H "X-Redmine-Personal-Access-Token: $PAT" http://127.0.0.1:3001/users/current.json
curl -i "http://127.0.0.1:3001/users/current.json?key=$PAT"
```

- [ ] **Step 4: Verify UI with Playwright CLI**

Use `/Users/ilyagmirin/.codex/skills/playwright/scripts/playwright_cli.sh` to log in, create a PAT, confirm one-time token display, visit admin list, and revoke.

- [ ] **Step 5: Commit delivery docs**

Commit message: `Document personal access token delivery`
