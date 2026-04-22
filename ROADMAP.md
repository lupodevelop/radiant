# Radiant — Roadmap

---

## v1.2.0 — Completeness *(additive, no breaking changes)*

Closes gaps that make the library incomplete for real-world API development.

### Query parameters (typed)
`query` and `queries` already exist. Add typed variants:
- `query_int(req, key) -> Result(Int, Nil)`
- `query_float(req, key) -> Result(Float, Nil)`
- `query_bool(req, key) -> Result(Bool, Nil)` — `"true"/"1"` → `True`, `"false"/"0"` → `False`

### Response helpers with body
Current `bad_request()`, `not_found()`, etc. return empty bodies — useless for REST APIs.
Add `_with` variants for all 4xx/5xx helpers:
- `bad_request_with(body)`, `not_found_with(body)`, `unauthorized_with(body)`
- `forbidden_with(body)`, `unprocessable_entity_with(body)`, `internal_server_error_with(body)`
- `json_error(status, message)` — returns `{"error": "message"}` with `application/json`

### Documentation
- Fix Quick Example in README: `get1` as default, not `let assert Ok(id) = int_param(...)`.
- Add `docs/` folder with structured reference pages.
- Add "Why Radiant vs native pattern matching" comparison table.

---

## v1.5.0 — Middleware depth *(minor breaking on internals)*

Completes the middleware stack to reach production readiness without Wisp.

### Form body parsing
- `form_body(req) -> Result(List(#(String, String)), Nil)` — `application/x-www-form-urlencoded`
- `form_param(req, name) -> Result(String, Nil)`
- `multipart_body(req) -> Result(List(FormField), Nil)` — at minimum text fields; binary file fields as `FileField`

### Method override middleware
For HTML forms that must simulate PUT/DELETE via POST with a `_method` field.
- `method_override() -> Middleware`

### Key conflict detection
`Key(a)` collision (two `key("user")` with different phantom types) is a silent runtime bug.
Add `validate_keys(router) -> Result(Router, List(String))` that inspects registered middleware
and returns a list of conflicting key names. Not a compile-time fix (impossible in Gleam without macros),
but makes the runtime error explicit and actionable.

---

## v2.0.0 — Architecture & JS target *(breaking)*

Strategic refactor targeting Gleam's full ecosystem (BEAM + JS).

### Module split
```
src/
  radiant.gleam              -- public re-export (unchanged import path)
  radiant/
    router.gleam             -- trie, matching, dispatch (pure, JS+BEAM)
    request.gleam            -- Request accessors (pure, JS+BEAM)
    response.gleam           -- response builders (pure, JS+BEAM)
    params.gleam             -- Param(a), path+query params (pure, JS+BEAM)
    context.gleam            -- Key(a), set/get (pure, JS+BEAM)
    middleware.gleam         -- cors, log, rescue, form, json (JS+BEAM)
    static.gleam             -- serve_static (@target erlang)
    testing.gleam            -- test helpers (JS+BEAM)
    mist.gleam               -- Mist adapter (@target erlang)
```
`import radiant` continues to work — `radiant.gleam` re-exports everything.

### JS target
The routing core is already pure (no FFI). Isolate BEAM-only code with `@target(erlang)`:
- `serve_static` → `radiant/static.gleam`
- `rescue` (uses `exception`) → conditional compile
- `mist.gleam` adapter → `@target(erlang)`

Add a Node.js adapter (`radiant/node.gleam`) for JS target.

### Route-level middleware
Current model applies middleware globally. Add per-route composition:
```gleam
// Route-level: applied only to this handler
router |> radiant.get("/profile", radiant.with(auth_mw, profile_handler))

// Preferred idiomatic pattern (function composition)
let protected = fn(handler) { fn(req) { use user <- auth_required(req); handler(req, user) } }
router |> radiant.get1("/profile/<id:int>", user_id, protected(profile_handler))
```

### Extend typed routes to `get8`
Cover `get7` and `get8`. Add explicit note in README documenting the Gleam language limit
(no variadic generics) and the recommended workaround (custom struct grouping params).

## Known limitations (by design)

- **`get1`–`get6` arity cap**: Gleam has no variadic generics. This is a language limit, not a library limit.
  For more than 6 typed params, group them into a custom struct and use `str_param`/`int_param`.
- **`Key(a)` collision**: Two `key("user")` calls with different phantom types silently overwrite each other.
  Use fully-qualified names: `key("auth:user")`. See [docs/middleware.md](docs/middleware.md).
- **`path_for` is runtime-checked**: renaming a pattern capture without updating `path_for` callers
  returns `Error(Nil)` silently. Mitigate by sharing `Param` constants and using `path_for1`–`path_for6`.
- **No WebSockets, sessions, cookies, template rendering** — use Mist or Wisp directly for those.
