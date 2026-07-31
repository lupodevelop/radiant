# Radiant

[![Package Version](https://img.shields.io/hexpm/v/radiant)](https://hex.pm/packages/radiant)
[![Hex Docs](https://img.shields.io/badge/hex-docs-ffaff3)](https://hexdocs.pm/radiant/)

Radiant is a type-safe HTTP router for Gleam on the BEAM. It gives you structural route
priority, typed path parameters, reverse routing, composable middleware, and test helpers
without global state or macros.

```sh
gleam add radiant
```

## A first route

```gleam
import gleam/int
import radiant

pub const user_path = "/users/<id:int>"
pub const user_id = radiant.int("id")

pub fn router() -> radiant.Router {
  radiant.new()
  |> radiant.get("/", fn(_) { radiant.ok("hello") })
  |> radiant.get1(user_path, user_id, fn(_, id) {
    radiant.json("{\"id\":" <> int.to_string(id) <> "}")
  })
}
```

`get1` parses the integer before calling the handler. Invalid values do not reach the handler;
they fall through to the next matching route and eventually return 404.

## Why Radiant?

Use native pattern matching when an application has a small, fixed route table. Use Radiant when
the route table is shared across modules or you need these behaviours in one place:

| Need | Native matching | Radiant |
| --- | --- | --- |
| Typed path parameters | Parse in each handler | `get1`–`get6` |
| Literal/capture priority | Manual ordering | Structural priority |
| 405 and `Allow` | Manual | Automatic |
| HEAD semantics | Manual | Automatic |
| Reverse routing | Manual strings | `path_for1`–`path_for6` |
| Middleware composition | App-specific | Global `middleware` or handler `wrap` |
| Route contract tests | App-specific | `routes` and fluent assertions |

Radiant complements Mist and Wisp; it does not provide sessions, cookies, CSRF, templates, or
WebSockets.

## Choose your integration

- **Mist + Radiant**: the smallest BEAM server stack with Radiant's middleware.
- **Wisp + Radiant**: keep Wisp's cookies, CSRF, and request lifecycle while using Radiant routing.
- **Radiant testing helpers**: test the router without starting a server.

Start with [the five-minute quickstart](docs/quickstart.md), then read the
[basic usage guide](docs/basic_usage.md).

Examples in this repo use `import radiant`. Focused modules are also available under
`radiant/router`, `radiant/request`, `radiant/context`, `radiant/response`,
`radiant/middleware`, and `radiant/testing`.

## 2.0 highlights

- `RadiantError` replaces opaque `Error(Nil)` values in the facade's request accessors and
  reverse routing.
- `key_named` makes context key namespacing explicit.
- `wrap` applies middleware to one handler instead of the whole router.
- `query_route` and `query_method` support QUERY (RFC 10008).
- `any` covers GET, HEAD, POST, PUT, DELETE, OPTIONS, PATCH, TRACE, CONNECT, and QUERY.
- Composable request builders and `json_error_from` simplify handler and integration tests.

## Documentation

- [Quickstart](docs/quickstart.md)
- [Basic usage](docs/basic_usage.md)
- [Routing reference](docs/routing.md)
- [Errors and migration](docs/errors.md)
- [Middleware](docs/middleware.md)
- [Testing](docs/testing.md)
- [Mist and Wisp integrations](docs/integrations.md)
- [Roadmap](ROADMAP.md)

The `radiant/*` modules contain the focused implementation. The compatibility surface is the
top-level `radiant` module; application code should continue to import that facade.

## Development

```sh
gleam test
gleam format --check src test dev
gleam dev
```

The repository also includes focused runnable examples:

```sh
gleam run --module basic_example        # http://localhost:4001
gleam run --module typed_routes_example # http://localhost:4002
gleam run --module middleware_example   # http://localhost:4003
gleam run --module query_example        # http://localhost:4004
```
