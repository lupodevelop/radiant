import radiant

import example_support as support

pub fn main() {
  let router =
    radiant.new()
    |> radiant.get("/search", fn(req) {
      case radiant.query(req, "q") {
        Ok(query) -> radiant.ok("Searching for: " <> query)
        Error(_) -> radiant.bad_request_with("missing query parameter: q")
      }
    })
    |> radiant.query_route("/search", fn(_req) {
      radiant.ok("QUERY method received")
    })

  support.serve(router, 4004)
}
