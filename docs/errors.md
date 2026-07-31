# Errors and migration to 2.0

Radiant 2.0 uses `RadiantError` instead of `Error(Nil)` for request accessors and reverse
routing. This keeps failures explicit without exposing internal request or router structures.

## Error variants

| Variant | Meaning |
| --- | --- |
| `MissingHeader(name)` | The request does not contain the header |
| `InvalidUtf8Body` | The body is not valid UTF-8 |
| `MissingPathParam(name)` | A path parameter was not captured or supplied |
| `InvalidIntParam(name, value)` | A captured path value is not an integer |
| `MissingQuery(name)` | The query parameter is absent |
| `InvalidIntQuery(name, value)` | The query value is not an integer |
| `InvalidFloatQuery(name, value)` | The query value is not a float |
| `InvalidBoolQuery(name, value)` | The query value is not `true`, `false`, `1`, or `0` |
| `MalformedQuery(value)` | The query string cannot be parsed |
| `MissingContext(name)` | No value was stored under the context key |

## Handling errors

```gleam
case radiant.query_int(req, "page") {
  Ok(page) -> list_page(page)
  Error(radiant.MissingQuery(_)) -> radiant.json_error(400, "page is required")
  Error(radiant.InvalidIntQuery(_, _)) ->
    radiant.json_error(400, "page must be an integer")
  Error(radiant.MalformedQuery(_)) ->
    radiant.json_error(400, "malformed query string")
  Error(_) -> radiant.bad_request()
}
```

Use `_` only for a deliberate fallback. Matching the named variants makes API responses more
useful and prevents accidental conversion of malformed input into a generic 404.

## Reverse routing

```gleam
case radiant.path_for1(user_path, user_id, id) {
  Ok(path) -> radiant.redirect(path)
  Error(radiant.MissingPathParam(name)) ->
    radiant.internal_server_error_with("route is missing " <> name)
  Error(_) -> radiant.internal_server_error()
}
```

Path parameter values are percent-encoded. Wildcard values preserve `/` separators while
encoding each individual segment.

## Context keys

Use a namespace for every key:

```gleam
pub const user_key = radiant.key_named("auth", "user")
```

`Key(a)` protects the value type at compile time, but key identity remains name-based at runtime.
Namespacing avoids collisions between application and third-party middleware.

## Migrating from 1.x

1. Change the package version constraint to `>= 2.0.0 and < 3.0.0`.
2. Replace `Error(Nil)` branches with `Error(_)`, or match the relevant `RadiantError` variant.
3. Replace repeated names such as `radiant.key("user")` with `radiant.key_named("module", "user")`.
4. Use `radiant.wrap(middleware, handler)` for middleware that should affect one route only.
