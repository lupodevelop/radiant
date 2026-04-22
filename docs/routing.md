# Routing Reference

## Pattern syntax

| Pattern              | Priority | Matches                        | Value in handler          |
|----------------------|----------|--------------------------------|---------------------------|
| `/users/admin`       | 1 — highest | exact string `admin`        | —                         |
| `/users/<id:int>`    | 2        | integer segments only          | `Int` via `get1` / `int_param` |
| `/users/:id`         | 3        | any segment                    | `String` via `str_param`  |
| `/users/<name:string>` | 3      | any segment (explicit form)    | `String` via `str_param`  |
| `/files/*rest`       | 4 — lowest | all remaining segments       | `String` joined with `/`  |

Priority is **structural**, not registration-order. `/users/admin` always beats `/users/<id:int>`,
even if the capture was registered first. `<id:int>` always beats `:name` for integer segments.

## Startup validations

Radiant panics at route registration (startup), not at request time, if:

- A `Param` name doesn't exist in the pattern (`validate_param`)
- Two captures of the same type exist at the same depth under the same prefix (`check_capture_ambiguity`)
- A wildcard `*name` appears before the last segment in a pattern
- Two captures in the same pattern share the same name

These are configuration errors — they should be caught in CI, not in production.

## Typed routes

```gleam
pub const user_id = radiant.int("id")
pub const post_id = radiant.int("pid")
pub const slug    = radiant.str("slug")

router
|> radiant.get1("/users/<id:int>", user_id, fn(_req, id) { ... })
|> radiant.get2("/users/<id:int>/posts/<pid:int>", user_id, post_id, fn(_req, uid, pid) { ... })
|> radiant.get1("/posts/<slug:string>", slug, fn(_req, s) { ... })
```

Variants exist for all methods: `get1`–`get6`, `post1`–`post6`, `put1`–`put6`, `patch1`–`patch6`, `delete1`–`delete6`.

> **Language limit**: Gleam has no variadic generics. `get6` is the maximum arity available.
> For routes with more than 6 typed params, group them in a custom struct and use `str_param`/`int_param`.

## Reverse routing

Build URLs from pattern strings — no manual string concatenation:

```gleam
// Untyped — List(#(String, String))
radiant.path_for("/users/<id:int>", [#("id", "42")])
// → Ok("/users/42")

radiant.path_for("/users/<id:int>", [])
// → Error(Nil)  — missing param caught at runtime

// Typed — pass the same Param constants used for routing
radiant.path_for1("/users/<id:int>", user_id, 42)
// → Ok("/users/42")

radiant.path_for2("/users/<id:int>/posts/<pid:int>", user_id, 1, post_id, 99)
// → Ok("/users/1/posts/99")
```

**Rename safety**: if you share the same `Param` constant between route registration and `path_for`,
updating the constant's name is enough — `validate_param` panics at startup if the name no longer
matches the pattern.

**Pattern reuse**: define pattern strings as module-level constants to keep routing and URL building in sync:

```gleam
pub const user_path = "/users/<id:int>"

router |> radiant.get1(user_path, user_id, handler)

radiant.path_for1(user_path, user_id, 42)
```

## Route introspection

```gleam
radiant.routes(router)
// → [
//   #(http.Get,  "/"),
//   #(http.Get,  "/users/<id:int>"),
//   #(http.Post, "/users"),
// ]
```

Useful for startup logging, contract tests, or API documentation generation.

## Automatic behaviours

**405 Method Not Allowed**: if a path matches but the method doesn't, Radiant returns 405 with a
correct `Allow` header listing registered methods. No manual handling needed.

**HEAD → GET fallback**: HEAD requests automatically fall through to the registered GET handler
and strip the response body, per RFC 9110 §9.3.2.

**Trailing slashes**: `/users` and `/users/` route to the same handler. Radiant filters empty
segments when splitting paths, so no configuration or redirect is needed.
