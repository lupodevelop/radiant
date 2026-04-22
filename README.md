# radiant

[![Package Version](https://img.shields.io/hexpm/v/radiant)](https://hex.pm/packages/radiant)
[![Hex Docs](https://img.shields.io/badge/hex-docs-ffaff3)](https://hexdocs.pm/radiant/)

A focused, type-safe HTTP router for Gleam on BEAM.

Built on a **prefix tree** with specificity-based priority, no global state, no macros.

```sh
gleam add radiant
```

## Quick start

```gleam
import gleam/int
import radiant

pub const user_id = radiant.int("id")

pub fn router() -> radiant.Router {
  radiant.new()
  |> radiant.get("/", fn(_req) { radiant.ok("hello") })
  |> radiant.get1("/users/<id:int>", user_id, fn(_req, id) {
    radiant.json("{\"id\":" <> int.to_string(id) <> "}")
  })
  |> radiant.scope("/api/v1", fn(r) {
    r |> radiant.post("/items", create_item)
  })
}
```

`get1` hands the parsed `Int` directly to the handler — no `let assert`, no `int.parse`.

## Why Radiant?

Gleam's native routing is `case wisp.path_segments(req)` — great for small apps. Radiant adds:

| | Native pattern matching | Radiant |
| --- | --- | --- |
| Type-safe path params | ❌ | ✅ |
| Specificity-based priority | ❌ | ✅ |
| 405 Method Not Allowed | manual | ✅ automatic |
| HEAD support (RFC 9110) | manual | ✅ automatic |
| Reverse routing | ❌ | ✅ |
| Route introspection | ❌ | ✅ |
| Built-in test helpers | ❌ | ✅ |
| CORS middleware | ❌ | ✅ |
| Query params (typed) | manual | ✅ |

## Features

- **Prefix tree**: O(1) literal lookup; cost grows with path depth, not route count.
- **Specificity priority**: `Literal > <id:int> > <name:string> > *wildcard`, regardless of registration order.
- **Typed routes** (`get1`–`get6`): handlers receive parsed `Int`/`String` values directly.
- **Type-safe context**: pass data through middlewares via `Key(a)` — no `Dynamic`, no manual decoding.
- **Automatic 405 + HEAD**: correct `Allow` header and HEAD→GET fallback built in.
- **Startup validations**: wildcard position, duplicate capture names, and capture ambiguity checked at registration, not at request time.
- **Swappable static server**: `FileSystem` interface works with `simplifile` or any IO library.
- **Testing helpers**: synthetic requests and fluent assertions — no running server needed.

## Documentation

- [Quickstart](docs/quickstart.md) — first working server in 5 minutes
- [Basic usage](docs/basic_usage.md) — routing, params, context, response helpers, query params
- [Routing reference](docs/routing.md) — patterns, priority, scope/mount, reverse routing
- [Middleware](docs/middleware.md) — built-in middleware and custom middleware patterns
- [Testing](docs/testing.md) — test helpers and assertions
- [Integrations](docs/integrations.md) — Mist and Wisp

## Non-goals

Radiant does not provide: template rendering, sessions, cookies, authentication, or WebSockets.
Use the underlying server (Mist) or a full framework (Wisp) directly for those.

## Development

```sh
gleam test    # Run the test suite
gleam dev     # Start the demo server on :4000
```
