import gleam/int
import radiant

import example_support as support

pub fn main() {
  let router =
    radiant.new()
    |> radiant.get1("/users/<id:int>", radiant.int("id"), fn(_req, id) {
      radiant.json("{\"id\":" <> int.to_string(id) <> "}")
    })

  support.serve(router, 4002)
}
