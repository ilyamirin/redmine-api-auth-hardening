# AI Workflow Notes

This implementation was developed with Codex assistance using a staged,
test-first workflow.

## Workflow

1. Reviewed the repository structure, Ruby environment, Redmine test setup, and
   the original task document.
2. Compared the agreed feature slice with the task requirements before editing
   code.
3. Planned the work as vertical slices:
   - data model, migration, settings;
   - REST API authentication;
   - user token management UI;
   - administrator controls and settings UI;
   - documentation and verification.
4. Wrote focused tests before each implementation slice.
5. Committed each completed slice separately with a descriptive message.

## AI Assistance

Codex was used to:

- inspect existing Redmine controller, route, view, locale, and test patterns;
- draft the implementation plan;
- write tests and implementation patches;
- run verification commands;
- perform direct REST API smoke checks;
- drive UI verification through Playwright.

Human decisions made during planning:

- implement an ambitious PAT lifecycle slice without scopes or rate limiting;
- use a dedicated `X-Redmine-Personal-Access-Token` header;
- keep legacy API keys compatible but avoid accepting PATs in URL parameters;
- store only token digests and show plaintext once;
- make expiration mandatory and admin-configurable.

## Verification

Verification includes focused automated tests for the model, API
authentication, user UI, administrator UI, and settings UI, plus manual smoke
checks through direct REST API requests and browser automation.
