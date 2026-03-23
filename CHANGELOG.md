# Changelog

All notable changes to this project will be documented here.

Format follows [Keep a Changelog](https://keepachangelog.com/en/1.1.0/).
Versioning follows [Semantic Versioning](https://semver.org/).

---

## [1.1.0] — 2026-03-23

- `get4`, `post4`, `put4`, `patch4`, `delete4` — typed route with four path parameters. Handler: `fn(Req, a, b, c, d) -> Response`.
- `get5`, `post5`, `put5`, `patch5`, `delete5` — typed route with five path parameters.
- `get6`, `post6`, `put6`, `patch6`, `delete6` — typed route with six path parameters.
- `path_for1`–`path_for6` — typed URL builders. Accept the same `Param` constants used for route registration instead of raw `(String, String)` pairs, making capture renames detectable at startup via `validate_param`.
- Capture ambiguity detection: `add_route_raw` panics at startup if two captures of the same type are registered at the same path depth under the same prefix, making order-dependent routing impossible to introduce silently.
- Wildcard position check: `ipath.parse` panics at startup if a wildcard (`*name`) appears before the last segment (e.g. `/files/*rest/download`). Segments after a wildcard are structurally unreachable.
- Duplicate capture name check: `ipath.parse` panics at startup if two captures or wildcards in the same pattern share the same name (e.g. `/users/<id:int>/posts/<id:int>`). Duplicate names cause silent dict overwrites in `req.params` at request time.
- Internal: `Param(a)` now carries a `to_string: fn(a) -> String` field (opaque — no public API change). Used by `path_for1`–`path_for6`.

---

## [1.0.0] — 2026-03-20

First stable release.

### Router construction

- `new()` — empty router with a default 404 fallback.
- `get`, `post`, `put`, `patch`, `delete` — register a route for a specific HTTP method.
- `options` — register a route for OPTIONS requests.
- `any(router, pattern, handler)` — register the same handler for all standard methods (GET, POST, PUT, PATCH, DELETE) in a single call.
- `scope(router, prefix, builder)` — group routes under a common path prefix.
- `mount(router, prefix, sub_router)` — attach an independent sub-router (with its own middleware stack) at a path prefix.
- `fallback(router, handler)` — custom handler for unmatched requests (default: 404).
- `middleware(router, mw)` — apply a middleware to the router; first added = outermost.

### Typed routes (`get1` / `get2` / `get3`)

- `get1`, `post1`, `put1`, `patch1`, `delete1` — typed route with one path parameter. Declare a `Param(a)` object; the handler receives the parsed, typed value directly. No `assert`, no `int.parse` in user code.
- `get2`, `post2`, `put2`, `patch2`, `delete2` — two typed parameters. Handler: `fn(Req, a, b) -> Response`.
- `get3`, `post3`, `put3`, `patch3`, `delete3` — three typed parameters. Handler: `fn(Req, a, b, c) -> Response`.
- `int(name) -> Param(Int)` — matches only integer path segments; delivers an `Int` to the handler.
- `str(name) -> Param(String)` — matches any segment; delivers a `String`.

### Typed path parameters in patterns

- `<id:int>` syntax — the route only matches when the segment is a valid integer; non-matching segments fall through to the next route automatically.
- `<name:string>` — explicit string capture (equivalent to `:name`).
- `*name` — wildcard; captures all remaining segments as a single string joined with `/`.
- `:name` — colon-style capture, alias for `<name:string>`.

### Match priority (structural, not registration-order)

Literal > `<id:int>` > `<name:string>` > `*wildcard`. A literal segment always takes priority over a capture regardless of which was registered first. `<id:int>` always takes priority over `<name:string>` for integer segments.

### Routing tree

Prefix tree (trie) backend. Literal segment lookup is O(1) via an internal `Dict`; captures and wildcards are tried only when no literal matches. For all-literal paths, matching cost is strictly O(path depth).

### Routing utilities

- `routes(router) -> List(#(Method, String))` — list all registered routes. Useful for startup logging, contract tests, and documentation generation.
- `path_for(pattern, params) -> Result(String, Nil)` — build a URL from a route pattern and a `(name, value)` list. Returns `Error(Nil)` if any named parameter is missing.

### Request accessors

- `method(req)` — HTTP method.
- `req_path(req)` — request path.
- `header(req, key)` — single header (case-insensitive).
- `headers(req)` — all headers.
- `body(req)` — raw `BitArray` body.
- `text_body(req)` — body decoded as UTF-8 string.
- `str_param(req, name)` — extract a path parameter as `String`.
- `int_param(req, name)` — extract a path parameter as `Int`.
- `query(req, key)` — single query parameter.
- `queries(req)` — all query parameters.
- `original(req)` — the underlying `Request(BitArray)`.

### Type-safe context

- `Key(a)` — opaque phantom-typed context key. Define as a module-level constant for maximum safety.
- `key(name) -> Key(a)` — constructor.
- `set_context(req, key, val)` — store any typed value in the request context.
- `get_context(req, key) -> Result(a, Nil)` — retrieve a typed value. No `Dynamic`, no manual decoding.

### Response helpers

- `ok(body)` — 200 with text body.
- `created(body)` — 201.
- `no_content()` — 204.
- `bad_request()` — 400.
- `unauthorized()` — 401.
- `forbidden()` — 403.
- `not_found()` — 404.
- `unprocessable_entity()` — 422.
- `internal_server_error()` — 500.
- `redirect(uri)` — 303 See Other.
- `json(body)` — 200 with `content-type: application/json; charset=utf-8`.
- `html(body)` — 200 with `content-type: text/html; charset=utf-8`.
- `response(status, body)` — arbitrary status with text body.
- `with_header(resp, key, value)` — add or overwrite a response header.

### Built-in middleware

- `cors(config)` / `default_cors()` — CORS with preflight support. `Access-Control-Allow-Origin` is only emitted when an `Origin` header is present.
- `json_body(key, decoder)` — parse the request body as JSON and store the decoded value in context under the given `Key(a)`. Returns 400 on failure. Skips parsing when the body is empty (GET, HEAD, DELETE pass through unaffected).
- `log(logger)` — log method, path, and response status. Compatible with `io.println`, `woof`, or any `fn(String) -> a`.
- `rescue(on_error)` — catch Erlang exceptions in handlers and return a custom response instead of crashing the process.
- `serve_static(prefix:, from:, via:)` — serve static files with MIME detection. Accepts a `FileSystem` interface so the underlying IO library is swappable.

### HEAD support

HEAD requests automatically fall through to the registered GET handler and return an empty body, per RFC 9110 §9.3.2.

### Server integration

- `handle(router, req) -> Response(BitArray)` — main dispatch entry point; works with Mist directly.
- `handle_with(router, req, body)` — accepts a request with any body type plus a separately read `BitArray`; designed for Wisp integration.

### Testing helpers

Request builders: `test_request`, `test_get`, `test_post`, `test_put`, `test_patch`, `test_delete`, `test_head`, `test_options`.

Fluent assertions (chainable, panic on failure):

- `should_have_status(resp, code)` — assert HTTP status.
- `should_have_body(resp, text)` — assert body text; failure shows actual vs expected.
- `should_have_header(resp, name, value)` — assert a header value.
- `should_have_json_body(resp, decoder) -> a` — parse body as JSON and return the decoded value.

### Runtime dependencies

`gleam_stdlib`, `gleam_http`, `gleam_json`, `exception`.
