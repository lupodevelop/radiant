import gleam/io
import radiant

import example_support as support

pub fn main() {
  let router =
    radiant.new()
    |> radiant.middleware(radiant.cors(radiant.default_cors()))
    |> radiant.middleware(radiant.log(io.println))
    |> radiant.get("/", fn(_req) { radiant.ok("Middleware is active") })

  support.serve(router, 4003)
}
