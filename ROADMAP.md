# Radiant roadmap

Radiant 2.0 is the stable baseline. The roadmap favours small, composable additions over
framework-level features that belong in Wisp or the application.

## 2.0 — current

- Typed route registration through `get1`–`get6` and equivalents.
- Structural route priority and startup validation.
- Detailed `RadiantError` values for request accessors and reverse routing.
- Global and handler-level middleware composition.
- JSON body parsing, CORS, logging, rescue, static files, and test helpers.
- QUERY support through `query_method` and `query_route`.
- Mist and Wisp integration examples.

## Next

### Documentation and examples

- Add a runnable example application covering JSON CRUD, CORS, auth context, and reverse routing.
- Add generated route-table output to the example application.
- Keep every external example compiling against the current public API.

### Request and response ergonomics

- Add typed helpers for common headers and content negotiation.
- Add response helpers for common JSON API envelopes.
- Consider a structured error returned by JSON body parsing while preserving middleware
  short-circuit behaviour.

### Testing

- Add property tests for route priority, percent encoding, and wildcard matching.
- Add contract tests for `Allow`, HEAD, OPTIONS, QUERY, and CORS preflight behaviour.
- Add a documented coverage command once the project adopts a coverage tool.

## Deliberately out of scope

Radiant will not grow sessions, cookies, CSRF, WebSockets, template rendering, or a database
layer. Use Wisp or focused libraries for those concerns.

The `get1`–`get6` limit is a Gleam language constraint. For more parameters, group values in a
domain type and use a small parsing function in the handler.
