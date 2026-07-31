import radiant

import example_support as support

pub fn main() {
  let router =
    radiant.new()
    |> radiant.get("/", fn(_req) { radiant.ok("Hello from Radiant") })
    |> radiant.get("/health", fn(_req) { radiant.json("{\"ok\":true}") })

  support.serve(router, 4001)
}
