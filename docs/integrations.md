# Server Integrations

## Mist

Direct integration — no adapter layer:

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

`radiant.handle` accepts `Request(BitArray)` — exactly what Mist provides. The only wrapping
needed is converting `BitArray` to `mist.Bytes` in the response body.

## Wisp

Wisp uses a `Connection` body type, so the body must be read before passing to Radiant:

```gleam
import radiant
import wisp

pub fn handle_request(req: wisp.Request) -> wisp.Response {
  use <- wisp.log_request(req)
  use body <- wisp.require_bit_array_body(req)
  radiant.handle_with(router, req, body)
}
```

`handle_with` accepts a request with any body type plus a separately-read `BitArray`, bridging
Wisp's body model with Radiant's.

### When to use Mist + Radiant vs Wisp + Radiant

**Use Mist + Radiant** when you want Radiant's middleware stack (CORS, logging, rescue, JSON body)
and don't need Wisp's features (signed cookies, CSRF, session management).

**Use Wisp + Radiant** when you need Wisp's middleware (especially signed cookies or CSRF) but want
Radiant's typed routing and testing helpers instead of Wisp's pattern-matching router.

Note: if you're already using Wisp's middleware heavily, the integration surface is narrow. The
main win from adding Radiant is typed path params and built-in test helpers.
