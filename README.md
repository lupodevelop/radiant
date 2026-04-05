# radiant

[![Package Version](https://img.shields.io/hexpm/v/radiant)](https://hex.pm/packages/radiant)
[![Hex Docs](https://img.shields.io/badge/hex-docs-ffaff3)](https://hexdocs.pm/radiant/)

A focused, type-safe HTTP router for Gleam on BEAM.

Radiant is built on a **prefix tree** and provides a declarative, composable routing
experience with zero global state and no macros.

```sh
gleam add radiant
```

## Quick example

```gleam
import radiant
import gleam/int

pub fn router() -> radiant.Router {
  radiant.new()
  |> radiant.get("/", fn(_req) { radiant.ok("hello") })
  // Typed parameters: 404 if 'id' is not an integer
  |> radiant.get("/users/<id:int>", fn(req) {
    let assert Ok(id) = radiant.int_param(req, "id")
    radiant.json("{\"id\":" <> int.to_string(id) <> "}")
  })
  |> radiant.scope("/api/v1", fn(r) {
    r |> radiant.post("/items", create_item)
  })
}
```

## Features

- **Prefix Tree Backend**: Literal segment lookup is O(1) via an internal `Dict`; matching cost grows with path depth, not route count.
- **Specificity-based Priority**: Match priority follows `Literal > <id:int> > <name:string> > *wildcard`, regardless of registration order. No surprises.
- **Typed Parameters**: Constrain segments directly in the pattern: `/users/<id:int>` or `/docs/<name:string>`. Non-matching segments fall through to the next route.
- **Typed Routes** (`get1`/`get2`/`get3`): Declare `Param(a)` objects and the handler receives parsed, typed values directly — no `assert`, no string parsing in user code.
- **Router Mounting**: Compose large applications by mounting sub-routers: `router |> mount("/auth", auth_router)`.
- **Type-safe Context**: Pass strongly-typed data through the middleware chain using `Key(a)` — no `Dynamic`, no manual decoding.
- **JSON Middleware**: Built-in `json_body` for automatic parsing; the decoded value lands in context already typed.
- **Swappable Static Server**: Serve assets via the `serve_static` middleware with a `FileSystem` interface (works with `simplifile` or any other library).
- **Automatic 405**: Returns `Method Not Allowed` with the correct `Allow` header when a path matches but the method doesn't.
- **HEAD support**: HEAD requests automatically fall through to the registered GET handler and return an empty body, per RFC 9110.

## API

Everything is a single import: `import radiant`.

### Router Construction

| Function | Description |
| --- | --- |
| `radiant.new()` | Empty router (404 fallback) |
| `radiant.get`, `post`, `put`, `patch`, `delete` | Register a route for a specific method |
| `radiant.options(r, pattern, fn)` | Register a route for OPTIONS requests |
| `radiant.any(r, pattern, fn)` | Register a handler for all standard HTTP methods |
| `radiant.get1`, `post1`, `...` | Typed route — 1 path parameter delivered to the handler |
| `radiant.get2`, `post2`, `...` | Typed route — 2 path parameters delivered to the handler |
| `radiant.get3`, `post3`, `...` | Typed route — 3 path parameters delivered to the handler |
| `radiant.get4`, `post4`, `...` | Typed route — 4 path parameters delivered to the handler |
| `radiant.get5`, `post5`, `...` | Typed route — 5 path parameters delivered to the handler |
| `radiant.get6`, `post6`, `...` | Typed route — 6 path parameters delivered to the handler |
| `radiant.scope(r, prefix, fn)` | Group routes under a prefix |
| `radiant.mount(r, prefix, sub)` | Attach a pre-built sub-router to a prefix |
| `radiant.middleware(r, mw)` | Apply a middleware to the router |
| `radiant.fallback(r, handler)` | Custom handler for unmatched requests |
| `radiant.routes(r)` | List all registered routes as `(Method, String)` pairs |

### Path Parameter Objects

| Constructor | Type | Matches |
| --- | --- | --- |
| `radiant.int("name")` | `Param(Int)` | Integer segments only — the handler receives an `Int` |
| `radiant.str("name")` | `Param(String)` | Any segment — the handler receives a `String` |

### Request & Context

| Function | Description |
| --- | --- |
| `radiant.key(name)` | Create a typed context key `Key(a)` |
| `radiant.set_context(req, key, val)` | Store any typed value in the request context |
| `radiant.get_context(req, key)` | Retrieve a typed value — returns `Result(a, Nil)` |
| `radiant.str_param(req, name)` | Extract a path segment as `String` |
| `radiant.int_param(req, name)` | Extract a path segment as `Int` |
| `radiant.text_body(req)` | Get the request body as a UTF-8 string |

### Response Helpers

| Function | Status | Description |
| --- | --- | --- |
| `radiant.ok(body)` | 200 | Plain text response |
| `radiant.created(body)` | 201 | Resource created |
| `radiant.no_content()` | 204 | Empty response |
| `radiant.bad_request()` | 400 | Malformed request |
| `radiant.unauthorized()` | 401 | Authentication required |
| `radiant.forbidden()` | 403 | Access denied |
| `radiant.not_found()` | 404 | Resource not found |
| `radiant.unprocessable_entity()` | 422 | Semantic validation failure |
| `radiant.internal_server_error()` | 500 | Server-side failure |
| `radiant.redirect(uri)` | 303 | See Other redirect |
| `radiant.json(body)` | 200 | Sets `content-type: application/json` |
| `radiant.html(body)` | 200 | Sets `content-type: text/html` |
| `radiant.with_header(resp, k, v)` | — | Add/overwrite a response header |

### Specialized Middlewares

#### JSON Body Parsing

Define a `Key(a)` constant to share between the middleware and the handler:

```gleam
pub const user_key: radiant.Key(User) = radiant.key("user")

let user_decoder = {
  use name <- decode.field("name", decode.string)
  decode.success(User(name))
}

router
|> radiant.middleware(radiant.json_body(user_key, user_decoder))
|> radiant.post("/users", fn(req) {
  // get_context returns Result(User, Nil) — no Dynamic, no decoding
  let assert Ok(user) = radiant.get_context(req, user_key)
  radiant.ok("Hello " <> user.name)
})
```

#### Static File Serving

Radiant uses a `FileSystem` interface so you can use `simplifile` now or swap later:

```gleam
let fs = radiant.FileSystem(read_bits: simplifile.read_bits, is_file: simplifile.is_file)
router |> radiant.middleware(radiant.serve_static("/assets", "public", fs))
```

## Typed Routes

`get1` through `get6` (and their `post`, `put`, `patch`, `delete` variants) let you
declare `Param(a)` objects and receive parsed, typed values directly in the handler —
no `assert`, no string parsing in user code.

```gleam
import radiant

// Declare params once — reuse for routing and URL building
pub const user_id = radiant.int("id")
pub const post_id = radiant.int("pid")

pub fn router() -> radiant.Router {
  radiant.new()
  // Handler receives (req, Int) — id is already an Int
  |> radiant.get1("/users/<id:int>", user_id, fn(req, id) {
    radiant.json("{\"id\":" <> int.to_string(id) <> "}")
  })
  // Handler receives (req, Int, Int) — both params parsed
  |> radiant.get2("/users/<id:int>/posts/<pid:int>", user_id, post_id, fn(req, uid, pid) {
    radiant.json("{\"user\":" <> int.to_string(uid) <> ",\"post\":" <> int.to_string(pid) <> "}")
  })
}
```

**Type safety guarantees:**

- The `Param(Int)` / `Param(String)` type propagates to the handler signature — mismatches are compile errors.
- At startup, if a `Param` name does not appear in the pattern, Radiant panics immediately with a clear message.
- No `Dynamic`, no `assert Ok(...)`, no manual `int.parse` in handler code.

## Testing

Radiant provides **fluent assertions** and synthetic request helpers to test
your logic without a running server.

```gleam
pub fn my_test() {
  my_router()
  |> radiant.handle(radiant.test_get("/api/users/42"))
  |> radiant.should_have_status(200)
  |> radiant.should_have_json_body(user_decoder)
  |> should.equal(User(id: 42))
}
```

Request helpers: `test_get`, `test_post`, `test_put`, `test_patch`, `test_delete`, `test_head`, `test_options`, `test_request`.

Assertion helpers: `should_have_status`, `should_have_body`, `should_have_header`, `should_have_json_body`.

## With Mist

```gleam
import gleam/bytes_tree
import gleam/erlang/process
import gleam/http/response
import mist
import radiant

pub fn main() {
  let router = my_router()

  let assert Ok(_) =
    mist.new(fn(req) {
      let resp = radiant.handle(router, req)
      response.set_body(resp, mist.Bytes(bytes_tree.from_bit_array(resp.body)))
    })
    |> mist.port(8080)
    |> mist.start()

  process.sleep_forever()
}
```

## With Wisp

`wisp.Request` uses a `Connection` body type, so use `handle_with` which accepts
the body read separately:

```gleam
pub fn handle_request(req: wisp.Request) -> wisp.Response {
  use <- wisp.log_request(req)
  use body <- wisp.require_bit_array_body(req)
  radiant.handle_with(router, req, body)
}
```

If you don't need Wisp's middleware, use **Mist + radiant** directly.

## Context key namespacing

`radiant.key("user")` creates a `Key(a)` that is backed by the string `"user"`. If two
middlewares both call `key("user")` but expect different types, they silently overwrite
each other in the context dict and produce wrong values at runtime.

**Best practice:** always use a fully-qualified name that includes your module or library
prefix:

```gleam
// Instead of:
pub const user_key = radiant.key("user")

// Prefer:
pub const user_key = radiant.key("auth_middleware:user")
pub const session_key = radiant.key("session_middleware:session")
```

This is especially important when mixing third-party middleware libraries.

## Trailing slashes

Radiant filters empty segments when splitting paths, so `/users` and `/users/` are
routed to the **same handler** by default. No configuration needed — this behaviour
is intentional and zero-cost.

## Reverse routing

Build URLs from patterns — no string concatenation, no broken links:

```gleam
radiant.path_for("/users/<id:int>", [#("id", "42")])
// → Ok("/users/42")

radiant.path_for("/users/<uid:int>/posts/<pid:int>", [
  #("uid", "1"), #("pid", "99"),
])
// → Ok("/users/1/posts/99")

radiant.path_for("/users/<id:int>", [])
// → Error(Nil)  ← missing param caught at runtime
```

### Typed reverse routing (`path_for1`–`path_for6`)

When you share the same `Param` constant between route registration and URL building,
renaming a capture is safe: `validate_param` panics at startup if the constant's name
no longer matches the pattern, so inconsistencies are caught immediately.

```gleam
pub const user_id = radiant.int("id")
pub const post_id = radiant.int("pid")

// Route
router |> radiant.get2("/users/<id:int>/posts/<pid:int>", user_id, post_id, handler)

// URL — no raw strings, no silent Error(Nil) from typos
radiant.path_for2("/users/<id:int>/posts/<pid:int>", user_id, 42, post_id, 7)
// → Ok("/users/42/posts/7")
```

Use the same pattern string for both routing and URL generation:

```gleam
pub const user_path = "/users/<id:int>"

// Register the route
router |> radiant.get(user_path, user_handler)

// Build a redirect URL
radiant.path_for(user_path, [#("id", int.to_string(new_id))])
|> result.map(radiant.redirect)
```

## Route introspection

List all registered routes — useful for startup logging, contract tests,
or generating documentation:

```gleam
radiant.routes(my_router())
// → [
//   #(http.Get,  "/"),
//   #(http.Get,  "/users/<id:int>"),
//   #(http.Post, "/users"),
// ]
```

## Path parameter syntax

| Pattern | Priority | Matches | Captured as |
| --- | --- | --- | --- |
| `/users/admin` | 1 — highest | exact string `admin` | — |
| `/users/<id:int>` | 2 | integer segments only | `String` (use `int_param` or `get1` with `radiant.int`) |
| `/users/:id` or `<name:string>` | 3 | any segment | `String` |
| `/files/*rest` | 4 — lowest | all remaining segments | `String` (joined with `/`) |

Priority is **structural**, not based on registration order. `/users/admin` always
matches before `/users/<id:int>`, even if the capture was registered first.
`<id:int>` always matches before `<name:string>` for integer segments.

Use `get1`/`get2`/`get3` (up to `get6`) with `radiant.int("id")` to receive the value already
parsed — no `int_param` call needed in the handler.

## Non-goals

Radiant does not provide: template rendering, sessions, cookies, authentication,
or WebSockets. For those, use the underlying server (Mist) or a full framework
(Wisp) directly.

## Development

```sh
gleam test    # Run the test suite
gleam dev     # Start the demo server on :4000
```
