# Testing

Radiant provides request builders and fluent assertions to test handlers without a running
server. The same helpers are available from `radiant/testing`.

## Request builders

```gleam
radiant.test_get("/users/42")
radiant.test_post("/users", "{\"name\":\"alice\"}")
radiant.test_put("/users/1", "{\"name\":\"bob\"}")
radiant.test_patch("/users/1", "{\"active\":true}")
radiant.test_delete("/users/42")
radiant.test_head("/users/42")
radiant.test_options("/users")
radiant.test_request(radiant.query_method, "/search")

// Query strings
radiant.test_get("/search?q=gleam&page=2")

// Custom method or headers
radiant.test_request(http.Get, "/users")
```

For requests built from several pieces, use the composable builder. Query values are
percent-encoded when the request is built:

```gleam
let req =
  radiant.request(http.Post, "/search")
  |> radiant.with_query("q", "gleam router")
  |> radiant.with_request_header("x-trace", "test")
  |> radiant.with_request_body("{\"page\":2}")
  |> radiant.build()
```

## Assertion helpers

Status, body, and header assertions return the response for chaining. They panic with a
descriptive message on failure. `should_have_json_body` is a terminal helper: it decodes the
body and returns the decoded value.

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

In 2.0, request accessors return `RadiantError` values. Test the error branch directly when
the distinction matters:

```gleam
case radiant.query_int(req, "page") {
  Error(radiant.MissingQuery("page")) -> radiant.bad_request()
  Error(radiant.InvalidIntQuery("page", _)) -> radiant.bad_request()
  Ok(page) -> handle_page(page)
  Error(_) -> radiant.bad_request()
}
```

Use `error_message` for a stable human-readable message, or `json_error_from` when returning
an accessor error directly:

```gleam
case radiant.query_int(req, "page") {
  Error(error) -> radiant.json_error_from(400, error)
  Ok(page) -> handle_page(page)
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
    let req = request.set_header(req, "origin", "https://example.com")
    request.set_header(req, "access-control-request-method", "GET")
  }
  |> fn(req) { radiant.handle(router, req) }
  |> radiant.should_have_status(204)
  |> radiant.should_have_header("access-control-allow-origin", "https://example.com")
}
```
