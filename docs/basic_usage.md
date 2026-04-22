# Basic Usage

## Registering routes

```gleam
radiant.new()
|> radiant.get("/users", list_users)
|> radiant.post("/users", create_user)
|> radiant.put("/users/<id:int>", update_user)
|> radiant.patch("/users/<id:int>", patch_user)
|> radiant.delete("/users/<id:int>", delete_user)
|> radiant.options("/users", options_users)  // custom OPTIONS handling
|> radiant.any("/health", health_handler)    // all methods → same handler
```

## Path parameters

**Untyped** — extract manually in the handler:

```gleam
radiant.get("/users/<id:int>", fn(req) {
  case radiant.int_param(req, "id") {
    Ok(id) -> radiant.json("{\"id\":" <> int.to_string(id) <> "}")
    Error(_) -> radiant.not_found()
  }
})
```

**Typed** — use `get1`/`get2`/... and receive the parsed value directly:

```gleam
pub const user_id = radiant.int("id")

radiant.get1("/users/<id:int>", user_id, fn(_req, id) {
  // id: Int — already parsed, guaranteed by the router
  radiant.json("{\"id\":" <> int.to_string(id) <> "}")
})
```

## Query parameters

```gleam
radiant.get("/search", fn(req) {
  let q     = radiant.query(req, "q")         // Result(String, Nil)
  let page  = radiant.query_int(req, "page")  // Result(Int, Nil)
  let sort  = radiant.query_bool(req, "asc")  // Result(Bool, Nil) — "true"/"1" → True
  let price = radiant.query_float(req, "max") // Result(Float, Nil)
  let all   = radiant.queries(req)            // List(#(String, String))
  ...
})
```

## Response helpers

```gleam
radiant.ok("hello")                   // 200 text/plain
radiant.json("{\"ok\":true}")         // 200 application/json
radiant.html("<h1>hi</h1>")           // 200 text/html
radiant.created("resource created")   // 201
radiant.no_content()                  // 204 empty
radiant.redirect("/login")            // 303

// Error responses — empty body
radiant.bad_request()
radiant.unauthorized()
radiant.forbidden()
radiant.not_found()
radiant.unprocessable_entity()
radiant.internal_server_error()

// Error responses — with body (useful for REST APIs)
radiant.bad_request_with("missing field: email")
radiant.not_found_with("user not found")
radiant.unprocessable_entity_with("email already taken")

// Structured JSON error — {"error": "..."} with application/json
radiant.json_error(404, "user not found")
radiant.json_error(422, "email already taken")

// Custom status + headers
radiant.response(418, "I'm a teapot")
|> radiant.with_header("x-custom", "value")
```

## Type-safe context

Pass data from middleware to handlers without `Dynamic`:

```gleam
// Define the key as a module-level constant — shared between middleware and handler
pub const user_key: radiant.Key(User) = radiant.key("auth:user")

// In middleware: store the authenticated user
fn auth_middleware(next) {
  fn(req) {
    case authenticate(req) {
      Ok(user) -> next(radiant.set_context(req, user_key, user))
      Error(_) -> radiant.unauthorized()
    }
  }
}

// In handler: retrieve it — type-safe, no Dynamic
fn profile_handler(req) {
  let assert Ok(user) = radiant.get_context(req, user_key)
  radiant.ok("Hello " <> user.name)
}
```

> **Key namespacing**: use fully-qualified names (`"auth:user"` not `"user"`) to avoid
> silent collisions when mixing multiple middleware libraries. See [middleware.md](middleware.md).

## Grouping routes

**`scope`** — build routes under a prefix in one call:

```gleam
radiant.new()
|> radiant.scope("/api/v1", fn(r) {
  r
  |> radiant.get("/users", list_users)
  |> radiant.post("/users", create_user)
  |> radiant.get1("/users/<id:int>", user_id, show_user)
})
```

**`mount`** — attach a pre-built sub-router with its own middleware stack:

```gleam
let admin_router =
  radiant.new()
  |> radiant.middleware(require_admin)
  |> radiant.get("/users", admin_list_users)

radiant.new()
|> radiant.mount("/admin", admin_router)
```

`scope` builds routes in the parent context. `mount` preserves the sub-router's middleware stack independently.
