# CLAUDE.md

Guidance for Claude Code (claude.ai/code) when working in this repository.

## What This Is

`fopost` — the official Ruby SDK for the FoPost REST API, distributed on **RubyGems**.
It wraps the HTTP API in a `Fopost::Client` with typed resources, response models, and an
error class per status.

- **Ruby >= 3.1** (`required_ruby_version` in `fopost.gemspec`).
- **Zero runtime dependencies on purpose** — the gem talks over `net/http` from the standard
  library so it drops into any app without a version conflict. Do not add one.
- Version `0.2.0` in `lib/fopost/version.rb`, which the gemspec reads.

## Downstream Packages

These repos wrap this SDK and must be updated in lockstep:

- `fopost-rails` — Rails integration gem: initializer, config, background jobs, webhook receiving

**Whenever you change this SDK's public surface — a renamed method, a changed parameter,
a new or removed resource, a new error type, a bumped minimum language version — you must
open a matching PR in every repo listed above in the same session.** They are separate
git repos, checked out as siblings at `../fopost-<child>`. A parent release that silently
breaks a child is only discovered by the user who upgrades first.

Also bump the child's dependency constraint on this package and note the change in its
CHANGELOG when this package is released.

## Brand Rules

- The product is **FoPost** (`fopost.com`). Never write "OwlStack" — retired Aug 2026.
- Never write an email address anywhere: not in code, YARD comments, README, or the gemspec.
  Support is https://fopost.com/contact and the GitHub issues page.
- Never name AI providers or models, infrastructure vendors, hosting, or any person.
  The author is the brand / Porter Bridge, LLC.

## Architecture

```
lib/fopost.rb              requires everything; Fopost.new(**opts) is Fopost::Client.new
lib/fopost/
  client.rb                entry point; builds HTTP::Client, exposes one reader per resource
  errors.rb                Fopost::Error hierarchy + ErrorFactory
  model.rb models.rb       response model base and the concrete models
  platforms.rb             platform and status constants
  unset.rb                 UNSET sentinel for partial updates
  version.rb
  http/
    transport.rb           the seam: a module defining #call(method:, url:, headers:, body:)
    net_http_transport.rb  default implementation over net/http
    client.rb              headers, URL building, JSON coding, retry loop, decode, unwrap
    response.rb            status + downcased headers + raw body, pre-decode
  resources/
    base.rb                unwrap/parse_list/compact_unset/iso8601 helpers
    posts.rb accounts.rb account_groups.rb workspaces.rb labels.rb ai.rb inbox.rb ads.rb validate.rb media.rb
```

**Request flow.** `client.posts.create(...)` → `Resources::Posts` normalises content and
accounts and calls `http.post('/posts', body)` → `HTTP::Client#request` builds the URI, JSON
encodes, and enters the retry loop → `@transport.call(...)` returns an `HTTP::Response` →
`#decode` either raises through `ErrorFactory.build` or returns the parsed body → the resource
calls `unwrap` and hands the hash to a model.

- **`Fopost::HTTP::Transport` is the seam.** Implement `#call(method:, url:, headers:, body:)`
  returning a `Fopost::HTTP::Response` and pass the instance as `transport:` to
  `Fopost::Client.new`. `sleeper:` is a second injectable — a lambda taking seconds — so the
  retry wait can be recorded instead of slept.
- Models accept **either wire casing** (posts answer snake_case, accounts camelCase) and keep
  the untouched payload on `#raw`, so a field added server-side is never dropped.
- `Fopost::UNSET` distinguishes "not passed" from `nil`, so a partial update sends only the
  named fields (`Resources::Base#compact_unset`).
- `Resources::Posts#each` / `#each_page` walk the list endpoint a page at a time.

**Resources wired today:** `posts`, `accounts`, `workspaces`, `labels`, `ai`, `inbox`, `ads`, `validate`, `media`.
Coverage is uneven and that is deliberate — `labels` is `#list` only, `workspaces` is
`#list`/`#get`, `accounts` is `#list`/`#get`/`#health`/`#update`/`#move`. `inbox` (scope `inbox`) covers the
list, thread, conversation, read, refresh, reply, hide, delete and approval endpoints but not
`/inbox/chat/*` or the attachment stream. `ads` (scope `ads`) covers ads, connections,
audiences, targeting search and lead forms; `boost`, `create`, `set_status` and `delete` also
need `publish`. `validate` (scope `posts`) covers `/validate/post`, `/validate/length` and
`/validate/media`. `media` (scope `posts`) is direct upload only: `presign`, `complete` and
`upload_direct`, which PUTs the bytes through `HTTP::Client#put_raw` with no API key. There is
no `communities`, `webhooks`, `analytics`, or `automations` resource; reach those through
`Fopost::Client#request` until one is added.

## API Contract

- **Base URL:** `Fopost::HTTP::Client::DEFAULT_BASE_URL` = `https://api.fopost.com/v1`
  (re-exported as `Fopost::Client::DEFAULT_BASE_URL` and `Fopost::DEFAULT_BASE_URL`). That is
  the path the API serves and the docs publish; `/api/v1` is **not** served and returns 404 —
  never reintroduce it. Only a trailing slash is stripped — pass the full path when
  overriding. There is **no `FOPOST_BASE_URL` env read**; use the `base_url:` keyword.
- **Auth:** header `X-API-Key: <key>`, never Bearer. The key falls back to `ENV['FOPOST_API_KEY']`;
  a missing key raises `Fopost::ConfigurationError` before any request goes out.
- **Headers on every request:** `Accept: application/json`, `Content-Type: application/json`,
  `X-API-Key`, `User-Agent: fopost-ruby/<VERSION>`.
- **Timeout:** 30.0s default, applied by `NetHTTPTransport` as read, write, and open timeout.
- **Retries — as implemented here:** `max_retries` (default 3) is the **total attempt count**,
  and only **HTTP 429** is retried. 5xx and network errors are **not** retried — a `net/http`
  exception propagates from the transport untouched. There is **no exponential backoff**: the
  wait is `Retry-After` (delta-seconds or an HTTP date) when present, otherwise a flat `1.0`s,
  capped at `MAX_RETRY_WAIT` = 60.0s.
- **Success envelope:** `Fopost::HTTP::Client.unwrap` peels `{"data": ...}` only when the key is
  present, because some endpoints answer bare. Paginated lists carry a sibling `meta`
  (`current_page`, `per_page`, `total`, `last_page`, `from`, `to`) parsed by `Fopost::PageMeta`;
  the inbox lists answer `{ page, perPage, total }`, parsed by `Fopost::InboxPageMeta`.
- **Wire casing differs per family.** Inbox and ads responses are camelCase. Inbox query params
  and the `/inbox/read` and `/inbox/refresh` bodies are snake_case; `PATCH /inbox/{id}` and every
  ads body are camelCase. The resources translate; callers always pass snake_case keywords.
- **Error envelope:** `{"error": "<code>", "message": "<text>"}` maps onto `Error#code` and
  `Error#message`; the parsed body stays on `#body`. `PaymentRequiredError#upgrade_url` and
  `ValidationError#errors` read off that body. `Error#to_s` renders `[<status> (<code>)] <message>`.
- **Error map** (`ErrorFactory::BY_STATUS`): 400/422 `ValidationError` · 401 `AuthenticationError` ·
  402 `PaymentRequiredError` · 403 `PermissionDeniedError` · 404 `NotFoundError` ·
  429 `RateLimitError` (has `#retry_after`) · **everything else, 5xx included, falls back to
  `Fopost::Error` itself** — there is no dedicated server-error class. Everything is rescuable
  as `Fopost::Error`; `ConfigurationError` is a plain `StandardError` and is not.
- **Rate-limit headers** (`X-RateLimit-Limit`/`-Remaining`/`-Reset`) are not surfaced on models
  or errors. They are readable via `Response#header` from a custom transport.

## Commands

```bash
bundle install
bundle exec rake test               # minitest, test/**/*_test.rb
bundle exec rake                    # default: test + rubocop
bundle exec rubocop
bundle exec rubocop -A              # autofix
bundle exec ruby -Ilib -Itest test/posts_test.rb   # one file
gem build fopost.gemspec            # build the .gem locally
```

CI (`.github/workflows/ci.yml`) runs `bundle exec rake test` on Ruby **3.1, 3.2, 3.3 and 3.4**,
and `bundle exec rubocop` once on 3.4.

## Conventions

- **RuboCop** (`~> 1.60`) with the `rubocop-minitest` plugin, `TargetRubyVersion: 3.1`,
  `NewCops: enable`. Config lives in `.rubocop.yml`; read it before working around a cop.
  Notable deliberate relaxations: `Layout/LineLength` max **120**, `Metrics` disabled,
  `Style/Documentation` disabled, `Naming/PredicatePrefix` disabled (`is_primary` mirrors the
  API field), `Style/RescueModifier` and `Style/FetchEnvVar` allowed.
- `# frozen_string_literal: true` on every file.
- Keyword arguments mirror the API's own parameter names, which is why
  `Naming/MethodParameterName` is loosened (and `q` allowed) rather than the names shortened.
- Comments stay short and explain a "why". YARD-style doc comments on public API methods are
  expected; no narrated comments on obvious code.

## Testing

- **Minitest**, tests in `test/`, shared setup in `test/test_helper.rb`.
- **`StubTransport` includes `Fopost::HTTP::Transport`.** It answers from a route table keyed
  by `[METHOD, path]` (`#stub(method, path, status:, json:)`), records every `Call` with its
  URI, headers and body, and raises if a request has no stub — so an unintended call is a test
  failure, not a network hit.
- `ClientHelpers#client` builds a `Fopost::Client` around that transport plus a `sleeper:`
  lambda that appends to `#slept`, letting `test/retry_test.rb` assert exact waits with no clock.
- Shared fixtures (`POST_FIXTURE`, `ACCOUNT_FIXTURE`, `WORKSPACE_FIXTURE`, `LABEL_FIXTURE`) are
  in `test_helper.rb` and deliberately mix snake_case and camelCase to pin the dual-casing reader.
  `test/inbox_test.rb` and `test/ads_test.rb` keep their camelCase fixtures local.
- **Tests never hit the live API.** No network call in the suite, ever, in CI or locally. If a
  change cannot be tested through `StubTransport`, the change is in the wrong layer.

## Releasing

**The `fopost` gem is NOT yet on RubyGems.** `.github/workflows/release.yml` exists and is
ready: it triggers on a `v*` tag (or manual dispatch), runs in the `rubygems` GitHub
environment, and publishes via `rubygems/release-gem@v1`.

It uses **RubyGems trusted publishing** (OIDC, `permissions: id-token: write`), so **no API-key
secret is referenced and none should be added.** First publish requires:

1. A RubyGems account that owns — or can claim — the `fopost` gem name.
2. A **trusted publisher** configured on rubygems.org for repository `fopost/fopost-ruby`,
   workflow `release.yml`, environment `rubygems`.
3. The `rubygems` environment created in GitHub repo settings (it gates who can trigger a release).
4. MFA on the owning account — the gemspec sets `rubygems_mfa_required: 'true'`.

The workflow already guards the release: it fails if the tag does not match
`Fopost::VERSION`, runs RuboCop and the full test suite, builds the gem, then installs the
built `.gem` and requires it in a clean process to catch a package that builds but is unusable.

To cut a release: bump `lib/fopost/version.rb`, add the section to `CHANGELOG.md`, commit, then
tag `v<version>`.

## Git

- **Conventional Commits** `<type>(<scope>): <description>` — one logical change per commit.
- Branch `feature/<description>` off a fresh `main`; merge to `main` via PR.
- **Never run `gh pr create`.** Push the branch and hand over the compare link:
  `https://github.com/fopost/fopost-ruby/compare/main...<branch>`
- Never `git stash` — use a worktree for parallel work.
