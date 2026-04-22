# Testing

Radiant provides request builders and fluent assertions to test handlers without a running server.

## Request builders

```gleam
radiant.test_get("/users/42")
radiant.test_post("/users", "{\"name\":\"alice\"}")
radiant.test_put("/users/1", "{\"name\":\"bob\"}")
radiant.test_patch("/users/1", "{\"active\":true}")
radiant.test_delete("/users/42")
radiant.test_head("/users/42")
radiant.test_options("/users")

// Query strings
radiant.test_get("/search?q=gleam&page=2")

// Custom method or headers
radiant.test_request(http.Get, "/users")
```

## Assertion helpers

All assertions return the response for chaining. They panic with a descriptive message on failure.

```gleam
router
|> radiant.handle(radiant.test_get("/users/42"))
|> radiant.should_have_status(200)
|> radiant.should_have_header("content-type", "application/json; charset=utf-8")
|> radiant.should_have_body("{\"id\":42}")

// Parse and return the decoded JSON value
let user =
  router
  |> radiant.handle(radiant.test_get("/users/42"))
  |> radiant.should_have_status(200)
  |> radiant.should_have_json_body(user_decoder)

user.name |> should.equal("alice")
```

## Full example

```gleam
import gleeunit/should
import radiant
import my_app

pub fn get_user_test() {
  my_app.router()
  |> radiant.handle(radiant.test_get("/users/1"))
  |> radiant.should_have_status(200)
  |> radiant.should_have_json_body(user_decoder)
  |> fn(u) { u.id |> should.equal(1) }
}

pub fn user_not_found_test() {
  my_app.router()
  |> radiant.handle(radiant.test_get("/users/999"))
  |> radiant.should_have_status(404)
}

pub fn wrong_method_test() {
  my_app.router()
  |> radiant.handle(radiant.test_post("/users/1", ""))
  |> radiant.should_have_status(405)
  |> radiant.should_have_header("allow", "GET")
}

pub fn non_integer_param_test() {
  // <id:int> pattern rejects non-integer segments → 404
  my_app.router()
  |> radiant.handle(radiant.test_get("/users/abc"))
  |> radiant.should_have_status(404)
}

pub fn json_body_middleware_test() {
  let body = "{\"name\":\"alice\",\"email\":\"alice@example.com\"}"

  my_app.router()
  |> radiant.handle(radiant.test_post("/users", body))
  |> radiant.should_have_status(201)
}

pub fn bad_json_body_test() {
  my_app.router()
  |> radiant.handle(radiant.test_post("/users", "not-json"))
  |> radiant.should_have_status(400)
}
```

## Testing middleware in isolation

```gleam
pub fn cors_test() {
  let router =
    radiant.new()
    |> radiant.middleware(radiant.cors(radiant.default_cors()))
    |> radiant.get("/", fn(_) { radiant.ok("ok") })

  radiant.test_request(http.Options, "/")
  |> fn(req) {
    // Add Origin header manually
    request.set_header(req, "origin", "https://example.com")
  }
  |> radiant.handle(router, _)
  |> radiant.should_have_status(204)
  |> radiant.should_have_header("access-control-allow-origin", "https://example.com")
}
```
