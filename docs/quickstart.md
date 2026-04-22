# Quickstart

## Install

```sh
gleam add radiant
gleam add mist gleam_erlang  # for the HTTP server
```

## Minimal server

```gleam
import gleam/bytes_tree
import gleam/erlang/process
import gleam/http/response
import gleam/int
import mist
import radiant

pub const user_id = radiant.int("id")

pub fn router() -> radiant.Router {
  radiant.new()
  |> radiant.get("/", fn(_req) { radiant.ok("hello") })
  |> radiant.get1("/users/<id:int>", user_id, fn(_req, id) {
    radiant.json("{\"id\":" <> int.to_string(id) <> "}")
  })
}

pub fn main() {
  let router = router()

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

```sh
gleam run
# → listening on :8080

curl localhost:8080/users/42
# → {"id":42}

curl localhost:8080/users/abc
# → 404  (non-integer segment doesn't match <id:int>)
```

## Key concepts

**`get1` / `get2` / ... `get6`** — typed routes. Declare a `Param(a)` constant once; the handler
receives the parsed value directly as the correct type. No `let assert`, no `int.parse`.

**`Param` constants** — define at module level and reuse for routing, URL building, and testing:

```gleam
pub const org_id  = radiant.int("org_id")
pub const proj_id = radiant.int("proj_id")

router
|> radiant.get2("/orgs/<org_id:int>/projects/<proj_id:int>", org_id, proj_id,
  fn(_req, oid, pid) { ... })

// Build the URL later — same constants, no raw strings
radiant.path_for2("/orgs/<org_id:int>/projects/<proj_id:int>", org_id, 7, proj_id, 3)
// → Ok("/orgs/7/projects/3")
```

**Middleware** — wrap the router, not individual routes:

```gleam
radiant.new()
|> radiant.middleware(radiant.cors(radiant.default_cors()))
|> radiant.middleware(radiant.log(io.println))
|> radiant.get("/", handler)
```

Next: [Basic usage](basic_usage.md) | [Routing reference](routing.md)
