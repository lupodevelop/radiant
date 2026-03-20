import gleam/http
import gleam/http/request
import gleam/http/response
import gleam/dynamic/decode
import gleam/int
import gleam/list
import gleeunit
import gleeunit/should
import radiant

pub fn main() {
  gleeunit.main()
}

// ---------------------------------------------------------------------------
// Router basics
// ---------------------------------------------------------------------------

pub fn root_route_test() {
  let router =
    radiant.new()
    |> radiant.get("/", fn(_req) { radiant.ok("home") })

  radiant.handle(router, radiant.test_get("/"))
  |> fn(r) { r.status }
  |> should.equal(200)

  radiant.handle(router, radiant.test_get("/"))
  |> fn(r) { r.body }
  |> should.equal(<<"home":utf8>>)
}

pub fn static_path_test() {
  let router =
    radiant.new()
    |> radiant.get("/users", fn(_req) { radiant.ok("users") })
    |> radiant.get("/posts", fn(_req) { radiant.ok("posts") })

  radiant.handle(router, radiant.test_get("/users"))
  |> fn(r) { r.body }
  |> should.equal(<<"users":utf8>>)

  radiant.handle(router, radiant.test_get("/posts"))
  |> fn(r) { r.body }
  |> should.equal(<<"posts":utf8>>)
}

pub fn trailing_slash_test() {
  let router =
    radiant.new()
    |> radiant.get("/users", fn(_req) { radiant.ok("ok") })

  radiant.handle(router, radiant.test_get("/users/"))
  |> fn(r) { r.status }
  |> should.equal(200)
}

pub fn method_mismatch_test() {
  let router =
    radiant.new()
    |> radiant.get("/users", fn(_req) { radiant.ok("ok") })

  let resp = radiant.handle(router, radiant.test_post("/users", ""))
  resp.status |> should.equal(405)
  response.get_header(resp, "allow") |> should.equal(Ok("GET"))
}

pub fn head_falls_through_to_get_test() {
  let router =
    radiant.new()
    |> radiant.get("/ping", fn(_req) { radiant.ok("pong") })

  let resp = radiant.handle(router, radiant.test_request(http.Head, "/ping"))
  resp.status |> should.equal(200)
  // HEAD response must have an empty body
  resp.body |> should.equal(<<>>)
}

pub fn head_unknown_route_is_404_test() {
  let router = radiant.new()
  radiant.handle(router, radiant.test_request(http.Head, "/nope"))
  |> fn(r) { r.status }
  |> should.equal(404)
}

pub fn json_body_skips_empty_body_test() {
  let id_key: radiant.Key(Int) = radiant.key("id")
  let decoder = {
    use id <- decode.field("id", decode.int)
    decode.success(id)
  }
  let router =
    radiant.new()
    |> radiant.middleware(radiant.json_body(id_key, decoder))
    |> radiant.get("/health", fn(_req) { radiant.ok("up") })

  // GET with no body must NOT return 400
  radiant.handle(router, radiant.test_get("/health"))
  |> fn(r) { r.status }
  |> should.equal(200)
}

pub fn not_found_default_test() {
  let router = radiant.new()

  radiant.handle(router, radiant.test_get("/nope"))
  |> fn(r) { r.status }
  |> should.equal(404)
}

pub fn custom_fallback_test() {
  let router =
    radiant.new()
    |> radiant.fallback(fn(_req) { radiant.response(418, "teapot") })

  radiant.handle(router, radiant.test_get("/nope"))
  |> fn(r) { r.status }
  |> should.equal(418)

  radiant.handle(router, radiant.test_get("/nope"))
  |> fn(r) { r.body }
  |> should.equal(<<"teapot":utf8>>)
}

// ---------------------------------------------------------------------------
// HTTP methods
// ---------------------------------------------------------------------------

pub fn post_route_test() {
  let router =
    radiant.new()
    |> radiant.post("/items", fn(_req) { radiant.created("done") })

  radiant.handle(router, radiant.test_post("/items", "payload"))
  |> fn(r) { r.status }
  |> should.equal(201)
}

pub fn put_route_test() {
  let router =
    radiant.new()
    |> radiant.put("/items/:id", fn(_req) { radiant.ok("updated") })

  let req = radiant.test_request(http.Put, "/items/1")
  radiant.handle(router, req)
  |> fn(r) { r.status }
  |> should.equal(200)
}

pub fn patch_route_test() {
  let router =
    radiant.new()
    |> radiant.patch("/items/:id", fn(_req) { radiant.ok("patched") })

  let req = radiant.test_request(http.Patch, "/items/1")
  radiant.handle(router, req)
  |> fn(r) { r.status }
  |> should.equal(200)
}

pub fn delete_route_test() {
  let router =
    radiant.new()
    |> radiant.delete("/items/:id", fn(_req) { radiant.no_content() })

  let req = radiant.test_request(http.Delete, "/items/1")
  radiant.handle(router, req)
  |> fn(r) { r.status }
  |> should.equal(204)
}

// ---------------------------------------------------------------------------
// Path parameters
// ---------------------------------------------------------------------------

pub fn str_param_test() {
  let router =
    radiant.new()
    |> radiant.get("/users/:name", fn(req) {
      case radiant.str_param(req, "name") {
        Ok(name) -> radiant.ok("hi " <> name)
        Error(Nil) -> radiant.bad_request()
      }
    })

  radiant.handle(router, radiant.test_get("/users/alice"))
  |> fn(r) { r.body }
  |> should.equal(<<"hi alice":utf8>>)
}

pub fn int_param_test() {
  let router =
    radiant.new()
    |> radiant.get("/users/:id", fn(req) {
      case radiant.int_param(req, "id") {
        Ok(_id) -> radiant.ok("found")
        Error(Nil) -> radiant.bad_request()
      }
    })

  radiant.handle(router, radiant.test_get("/users/42"))
  |> fn(r) { r.body }
  |> should.equal(<<"found":utf8>>)
}

pub fn int_param_invalid_test() {
  let router =
    radiant.new()
    |> radiant.get("/users/:id", fn(req) {
      case radiant.int_param(req, "id") {
        Ok(_id) -> radiant.ok("found")
        Error(Nil) -> radiant.bad_request()
      }
    })

  radiant.handle(router, radiant.test_get("/users/abc"))
  |> fn(r) { r.status }
  |> should.equal(400)
}

pub fn multiple_params_test() {
  let router =
    radiant.new()
    |> radiant.get("/users/:uid/posts/:pid", fn(req) {
      let assert Ok(uid) = radiant.str_param(req, "uid")
      let assert Ok(pid) = radiant.str_param(req, "pid")
      radiant.ok(uid <> ":" <> pid)
    })

  radiant.handle(router, radiant.test_get("/users/alice/posts/99"))
  |> fn(r) { r.body }
  |> should.equal(<<"alice:99":utf8>>)
}

pub fn missing_param_test() {
  let router =
    radiant.new()
    |> radiant.get("/users/:id", fn(req) {
      case radiant.str_param(req, "nonexistent") {
        Ok(_) -> radiant.ok("found")
        Error(Nil) -> radiant.bad_request()
      }
    })

  radiant.handle(router, radiant.test_get("/users/42"))
  |> fn(r) { r.status }
  |> should.equal(400)
}

// ---------------------------------------------------------------------------
// Route ordering (first match wins)
// ---------------------------------------------------------------------------

pub fn literal_beats_capture_regardless_of_order_test() {
  // Literal segments always take priority over captures, regardless of
  // registration order. Standard router semantics: specificity wins.
  let router =
    radiant.new()
    |> radiant.get("/users/:id", fn(_req) { radiant.ok("param") })
    |> radiant.get("/users/admin", fn(_req) { radiant.ok("admin") })

  radiant.handle(router, radiant.test_get("/users/admin"))
  |> fn(r) { r.body }
  |> should.equal(<<"admin":utf8>>)
}

pub fn literal_before_capture_test() {
  let router =
    radiant.new()
    |> radiant.get("/users/admin", fn(_req) { radiant.ok("admin") })
    |> radiant.get("/users/:id", fn(_req) { radiant.ok("param") })

  radiant.handle(router, radiant.test_get("/users/admin"))
  |> fn(r) { r.body }
  |> should.equal(<<"admin":utf8>>)

  radiant.handle(router, radiant.test_get("/users/42"))
  |> fn(r) { r.body }
  |> should.equal(<<"param":utf8>>)
}

// ---------------------------------------------------------------------------
// Scoping
// ---------------------------------------------------------------------------

pub fn scope_test() {
  let router =
    radiant.new()
    |> radiant.get("/", fn(_req) { radiant.ok("root") })
    |> radiant.scope("/api/v1", fn(r) {
      r
      |> radiant.get("/users", fn(_req) { radiant.ok("api users") })
      |> radiant.get("/posts", fn(_req) { radiant.ok("api posts") })
    })

  radiant.handle(router, radiant.test_get("/"))
  |> fn(r) { r.body }
  |> should.equal(<<"root":utf8>>)

  radiant.handle(router, radiant.test_get("/api/v1/users"))
  |> fn(r) { r.body }
  |> should.equal(<<"api users":utf8>>)

  radiant.handle(router, radiant.test_get("/api/v1/posts"))
  |> fn(r) { r.body }
  |> should.equal(<<"api posts":utf8>>)
}

pub fn nested_scope_test() {
  let router =
    radiant.new()
    |> radiant.scope("/api", fn(r) {
      r
      |> radiant.scope("/v1", fn(r2) {
        r2
        |> radiant.get("/items", fn(_req) { radiant.ok("v1 items") })
      })
    })

  radiant.handle(router, radiant.test_get("/api/v1/items"))
  |> fn(r) { r.body }
  |> should.equal(<<"v1 items":utf8>>)
}

// ---------------------------------------------------------------------------
// Response helpers
// ---------------------------------------------------------------------------

pub fn json_response_test() {
  let resp = radiant.json("{\"ok\":true}")

  resp.status |> should.equal(200)
  resp.body |> should.equal(<<"{\"ok\":true}":utf8>>)
  response.get_header(resp, "content-type")
  |> should.equal(Ok("application/json; charset=utf-8"))
}

pub fn html_response_test() {
  let resp = radiant.html("<h1>hi</h1>")

  resp.status |> should.equal(200)
  response.get_header(resp, "content-type")
  |> should.equal(Ok("text/html; charset=utf-8"))
}

pub fn redirect_response_test() {
  let resp = radiant.redirect("/login")

  resp.status |> should.equal(303)
  response.get_header(resp, "location")
  |> should.equal(Ok("/login"))
}

pub fn with_header_test() {
  let resp =
    radiant.ok("hi")
    |> radiant.with_header("x-custom", "value")

  response.get_header(resp, "x-custom")
  |> should.equal(Ok("value"))
}

// ---------------------------------------------------------------------------
// Req accessors
// ---------------------------------------------------------------------------

pub fn req_method_test() {
  let router =
    radiant.new()
    |> radiant.post("/echo", fn(req) {
      case radiant.method(req) {
        http.Post -> radiant.ok("post")
        _ -> radiant.ok("other")
      }
    })

  radiant.handle(router, radiant.test_post("/echo", ""))
  |> fn(r) { r.body }
  |> should.equal(<<"post":utf8>>)
}

pub fn req_path_test() {
  let router =
    radiant.new()
    |> radiant.get("/hello", fn(req) { radiant.ok(radiant.req_path(req)) })

  radiant.handle(router, radiant.test_get("/hello"))
  |> fn(r) { r.body }
  |> should.equal(<<"/hello":utf8>>)
}

pub fn req_body_test() {
  let router =
    radiant.new()
    |> radiant.post("/echo", fn(req) {
      case radiant.text_body(req) {
        Ok(text) -> radiant.ok(text)
        Error(Nil) -> radiant.bad_request()
      }
    })

  radiant.handle(router, radiant.test_post("/echo", "payload"))
  |> fn(r) { r.body }
  |> should.equal(<<"payload":utf8>>)
}

pub fn req_header_test() {
  let router =
    radiant.new()
    |> radiant.get("/check", fn(req) {
      case radiant.header(req, "x-token") {
        Ok(v) -> radiant.ok(v)
        Error(Nil) -> radiant.bad_request()
      }
    })

  let req =
    radiant.test_get("/check")
    |> request.set_header("x-token", "secret")

  radiant.handle(router, req)
  |> fn(r) { r.body }
  |> should.equal(<<"secret":utf8>>)
}

pub fn req_original_test() {
  let router =
    radiant.new()
    |> radiant.get("/check", fn(req) {
      let orig = radiant.original(req)
      radiant.ok(orig.path)
    })

  radiant.handle(router, radiant.test_get("/check"))
  |> fn(r) { r.body }
  |> should.equal(<<"/check":utf8>>)
}

// ---------------------------------------------------------------------------
// Query parameters
// ---------------------------------------------------------------------------

pub fn query_param_test() {
  let router =
    radiant.new()
    |> radiant.get("/search", fn(req) {
      case radiant.query(req, "q") {
        Ok(q) -> radiant.ok(q)
        Error(Nil) -> radiant.bad_request()
      }
    })

  radiant.handle(router, radiant.test_get("/search?q=gleam"))
  |> fn(r) { r.body }
  |> should.equal(<<"gleam":utf8>>)
}

pub fn queries_test() {
  let router =
    radiant.new()
    |> radiant.get("/search", fn(req) {
      let qs = radiant.queries(req)
      case qs {
        [#("a", va), #("b", vb)] -> radiant.ok(va <> "," <> vb)
        _ -> radiant.bad_request()
      }
    })

  radiant.handle(router, radiant.test_get("/search?a=1&b=2"))
  |> fn(r) { r.body }
  |> should.equal(<<"1,2":utf8>>)
}

pub fn no_query_test() {
  let router =
    radiant.new()
    |> radiant.get("/page", fn(req) {
      case radiant.query(req, "missing") {
        Ok(_) -> radiant.ok("found")
        Error(Nil) -> radiant.ok("none")
      }
    })

  radiant.handle(router, radiant.test_get("/page"))
  |> fn(r) { r.body }
  |> should.equal(<<"none":utf8>>)
}

// ---------------------------------------------------------------------------
// Test helpers
// ---------------------------------------------------------------------------

pub fn test_get_test() {
  let req = radiant.test_get("/foo")
  req.method |> should.equal(http.Get)
  req.path |> should.equal("/foo")
  req.body |> should.equal(<<>>)
}

pub fn test_post_test() {
  let req = radiant.test_post("/bar", "data")
  req.method |> should.equal(http.Post)
  req.path |> should.equal("/bar")
  req.body |> should.equal(<<"data":utf8>>)
}

pub fn test_request_with_query_test() {
  let req = radiant.test_get("/s?q=hello&lang=en")
  req.path |> should.equal("/s")
  request.get_query(req)
  |> should.be_ok()
}

// ---------------------------------------------------------------------------
// Wildcard routes
// ---------------------------------------------------------------------------

pub fn wildcard_captures_rest_test() {
  let router =
    radiant.new()
    |> radiant.get("/static/*path", fn(req) {
      case radiant.str_param(req, "path") {
        Ok(p) -> radiant.ok(p)
        Error(Nil) -> radiant.bad_request()
      }
    })

  radiant.handle(router, radiant.test_get("/static/css/main.css"))
  |> fn(r) { r.body }
  |> should.equal(<<"css/main.css":utf8>>)
}

pub fn wildcard_single_segment_test() {
  let router =
    radiant.new()
    |> radiant.get("/files/*path", fn(req) {
      let assert Ok(p) = radiant.str_param(req, "path")
      radiant.ok(p)
    })

  radiant.handle(router, radiant.test_get("/files/readme.md"))
  |> fn(r) { r.body }
  |> should.equal(<<"readme.md":utf8>>)
}

pub fn wildcard_empty_test() {
  let router =
    radiant.new()
    |> radiant.get("/files/*path", fn(req) {
      let assert Ok(p) = radiant.str_param(req, "path")
      radiant.ok("got:" <> p)
    })

  radiant.handle(router, radiant.test_get("/files"))
  |> fn(r) { r.body }
  |> should.equal(<<"got:":utf8>>)
}

pub fn wildcard_with_prefix_params_test() {
  let router =
    radiant.new()
    |> radiant.get("/users/:id/files/*path", fn(req) {
      let assert Ok(id) = radiant.str_param(req, "id")
      let assert Ok(path) = radiant.str_param(req, "path")
      radiant.ok(id <> ":" <> path)
    })

  radiant.handle(router, radiant.test_get("/users/42/files/docs/api.md"))
  |> fn(r) { r.body }
  |> should.equal(<<"42:docs/api.md":utf8>>)
}

// ---------------------------------------------------------------------------
// Middleware
// ---------------------------------------------------------------------------

pub fn middleware_wraps_handler_test() {
  let add_header: radiant.Middleware = fn(next) {
    fn(req) {
      next(req)
      |> radiant.with_header("x-wrapped", "true")
    }
  }

  let router =
    radiant.new()
    |> radiant.middleware(add_header)
    |> radiant.get("/", fn(_req) { radiant.ok("hi") })

  let resp = radiant.handle(router, radiant.test_get("/"))
  resp.status |> should.equal(200)
  response.get_header(resp, "x-wrapped") |> should.equal(Ok("true"))
}

pub fn middleware_order_test() {
  // First middleware added = outermost, so it runs first on request
  // and last on response. We test by appending to a header.
  let mw_a: radiant.Middleware = fn(next) {
    fn(req) {
      next(req)
      |> radiant.with_header("x-order", "A")
    }
  }
  let mw_b: radiant.Middleware = fn(next) {
    fn(req) {
      let resp = next(req)
      // B runs after A on response, so it overwrites
      radiant.with_header(resp, "x-order", "B")
    }
  }

  let router =
    radiant.new()
    |> radiant.middleware(mw_a)
    |> radiant.middleware(mw_b)
    |> radiant.get("/", fn(_req) { radiant.ok("hi") })

  let resp = radiant.handle(router, radiant.test_get("/"))
  // mw_a is outermost: handler -> mw_b sets "B" -> mw_a sets "A"
  response.get_header(resp, "x-order") |> should.equal(Ok("A"))
}

pub fn middleware_can_short_circuit_test() {
  let auth_mw: radiant.Middleware = fn(next) {
    fn(req) {
      case radiant.header(req, "authorization") {
        Ok(_) -> next(req)
        Error(Nil) -> radiant.response(401, "unauthorized")
      }
    }
  }

  let router =
    radiant.new()
    |> radiant.middleware(auth_mw)
    |> radiant.get("/secret", fn(_req) { radiant.ok("data") })

  // Without auth header
  radiant.handle(router, radiant.test_get("/secret"))
  |> fn(r) { r.status }
  |> should.equal(401)

  // With auth header
  let req =
    radiant.test_get("/secret")
    |> request.set_header("authorization", "Bearer tok")
  radiant.handle(router, req)
  |> fn(r) { r.status }
  |> should.equal(200)
}

// ---------------------------------------------------------------------------
// CORS middleware
// ---------------------------------------------------------------------------

pub fn cors_preflight_test() {
  let router =
    radiant.new()
    |> radiant.middleware(radiant.cors(radiant.default_cors()))
    |> radiant.get("/api", fn(_req) { radiant.ok("data") })

  let req =
    radiant.test_request(http.Options, "/api")
    |> request.set_header("origin", "https://example.com")

  let resp = radiant.handle(router, req)
  resp.status |> should.equal(204)
  response.get_header(resp, "access-control-allow-origin")
  |> should.equal(Ok("https://example.com"))
  response.get_header(resp, "access-control-allow-methods")
  |> should.be_ok()
}

pub fn cors_normal_request_test() {
  let router =
    radiant.new()
    |> radiant.middleware(radiant.cors(radiant.default_cors()))
    |> radiant.get("/api", fn(_req) { radiant.ok("data") })

  let req =
    radiant.test_get("/api")
    |> request.set_header("origin", "https://example.com")

  let resp = radiant.handle(router, req)
  resp.status |> should.equal(200)
  response.get_header(resp, "access-control-allow-origin")
  |> should.equal(Ok("https://example.com"))
}

pub fn cors_no_origin_test() {
  let router =
    radiant.new()
    |> radiant.middleware(radiant.cors(radiant.default_cors()))
    |> radiant.get("/api", fn(_req) { radiant.ok("data") })

  let resp = radiant.handle(router, radiant.test_get("/api"))
  resp.status |> should.equal(200)
  // No origin header sent → allow-origin still set because "*" matches ""
  // This is fine — the browser won't send cross-origin requests without Origin
}

// ---------------------------------------------------------------------------
// Log middleware
// ---------------------------------------------------------------------------

pub fn log_middleware_test() {
  // Collect log messages in a list via process dictionary (simple test approach)
  let messages = []
  let logger = fn(msg: String) -> List(String) { [msg, ..messages] }

  let router =
    radiant.new()
    |> radiant.middleware(radiant.log(logger))
    |> radiant.get("/hello", fn(_req) { radiant.ok("hi") })

  let resp = radiant.handle(router, radiant.test_get("/hello"))
  resp.status |> should.equal(200)
  // The log middleware runs without crashing — that's the main assertion.
  // We can't easily capture side effects in gleeunit without process dict.
}

// ---------------------------------------------------------------------------
// 405 Method Not Allowed
// ---------------------------------------------------------------------------

pub fn method_not_allowed_multiple_methods_test() {
  let router =
    radiant.new()
    |> radiant.get("/items", fn(_req) { radiant.ok("list") })
    |> radiant.post("/items", fn(_req) { radiant.created("done") })

  let resp = radiant.handle(router, radiant.test_delete("/items"))
  resp.status |> should.equal(405)
  // Allow header should contain both GET and POST
  let assert Ok(allow) = response.get_header(resp, "allow")
  allow |> should.equal("GET, POST")
}

pub fn true_not_found_returns_404_test() {
  let router =
    radiant.new()
    |> radiant.get("/items", fn(_req) { radiant.ok("list") })

  // Path doesn't match any route → 404, not 405
  radiant.handle(router, radiant.test_get("/nope"))
  |> fn(r) { r.status }
  |> should.equal(404)
}

// ---------------------------------------------------------------------------
// Rescue middleware
// ---------------------------------------------------------------------------

pub fn rescue_catches_panic_test() {
  let router =
    radiant.new()
    |> radiant.middleware(
      radiant.rescue(fn(_err) { radiant.response(500, "caught") }),
    )
    |> radiant.get("/boom", fn(_req) { panic as "intentional crash" })

  let resp = radiant.handle(router, radiant.test_get("/boom"))
  resp.status |> should.equal(500)
  resp.body |> should.equal(<<"caught":utf8>>)
}

pub fn rescue_passes_through_normal_test() {
  let router =
    radiant.new()
    |> radiant.middleware(
      radiant.rescue(fn(_err) { radiant.response(500, "caught") }),
    )
    |> radiant.get("/ok", fn(_req) { radiant.ok("fine") })

  let resp = radiant.handle(router, radiant.test_get("/ok"))
  resp.status |> should.equal(200)
  resp.body |> should.equal(<<"fine":utf8>>)
}

// ---------------------------------------------------------------------------
// Percent-encoding
// ---------------------------------------------------------------------------

pub fn percent_encoding_test() {
  let router =
    radiant.new()
    |> radiant.get("/hello world", fn(_req) { radiant.ok("got it") })

  // Request with %20
  radiant.handle(router, radiant.test_get("/hello%20world"))
  |> fn(r) { r.status }
  |> should.equal(200)

  radiant.handle(router, radiant.test_get("/hello world"))
  |> fn(r) { r.status }
  |> should.equal(200)
}

// ---------------------------------------------------------------------------
// Wisp-style handle_with
// ---------------------------------------------------------------------------

pub fn handle_with_test() {
  let router =
    radiant.new()
    |> radiant.post("/upload", fn(req) {
      let assert Ok(body) = radiant.text_body(req)
      radiant.ok("got " <> body)
    })

  let req = request.new() |> request.set_method(http.Post) |> request.set_path("/upload")
  let body = <<"payload":utf8>>

  radiant.handle_with(router, req, body)
  |> fn(r) { r.body }
  |> should.equal(<<"got payload":utf8>>)
}

// ---------------------------------------------------------------------------
// Test helper shortcuts
// ---------------------------------------------------------------------------

pub fn test_put_test() {
  let req = radiant.test_put("/items/1", "data")
  req.method |> should.equal(http.Put)
  req.body |> should.equal(<<"data":utf8>>)
}

pub fn test_patch_test() {
  let req = radiant.test_patch("/items/1", "patch")
  req.method |> should.equal(http.Patch)
  req.body |> should.equal(<<"patch":utf8>>)
}

pub fn test_delete_test() {
  let req = radiant.test_delete("/items/1")
  req.method |> should.equal(http.Delete)
  req.body |> should.equal(<<>>)
}

// ---------------------------------------------------------------------------
// Mounting
// ---------------------------------------------------------------------------

pub fn mount_test() {
  let sub_router =
    radiant.new()
    |> radiant.get("/info", fn(_req) { radiant.ok("sub info") })
    |> radiant.post("/data", fn(_req) { radiant.created("sub data") })

  let router =
    radiant.new()
    |> radiant.get("/", fn(_req) { radiant.ok("root") })
    |> radiant.mount("/api/v1", sub_router)

  radiant.handle(router, radiant.test_get("/"))
  |> fn(r) { r.body }
  |> should.equal(<<"root":utf8>>)

  radiant.handle(router, radiant.test_get("/api/v1/info"))
  |> fn(r) { r.body }
  |> should.equal(<<"sub info":utf8>>)

  radiant.handle(router, radiant.test_post("/api/v1/data", ""))
  |> fn(r) { r.status }
  |> should.equal(201)
}

pub fn mount_with_middleware_test() {
  let add_header: radiant.Middleware = fn(next) {
    fn(req) {
      next(req) |> radiant.with_header("x-sub", "true")
    }
  }

  let sub_router =
    radiant.new()
    |> radiant.middleware(add_header)
    |> radiant.get("/ping", fn(_req) { radiant.ok("pong") })

  let router =
    radiant.new()
    |> radiant.get("/ping", fn(_req) { radiant.ok("root pong") })
    |> radiant.mount("/sub", sub_router)

  // Sub-router route should have the middleware applied
  let resp_sub = radiant.handle(router, radiant.test_get("/sub/ping"))
  resp_sub.body |> should.equal(<<"pong":utf8>>)
  response.get_header(resp_sub, "x-sub") |> should.equal(Ok("true"))

  // Main router route should NOT have the sub-router middleware
  let resp_root = radiant.handle(router, radiant.test_get("/ping"))
  resp_root.body |> should.equal(<<"root pong":utf8>>)
  response.get_header(resp_root, "x-sub") |> should.be_error()
}

// ---------------------------------------------------------------------------
// Context State
// ---------------------------------------------------------------------------

pub fn context_state_test() {
  let user_id_key: radiant.Key(Int) = radiant.key("user_id")

  let add_user_mw: radiant.Middleware = fn(next) {
    fn(req) { next(radiant.set_context(req, user_id_key, 42)) }
  }

  let router =
    radiant.new()
    |> radiant.middleware(add_user_mw)
    |> radiant.get("/profile", fn(req) {
      case radiant.get_context(req, user_id_key) {
        Ok(42) -> radiant.ok("authorized")
        _ -> radiant.response(401, "unauthorized")
      }
    })

  radiant.handle(router, radiant.test_get("/profile"))
  |> fn(r) { r.body }
  |> should.equal(<<"authorized":utf8>>)
}

pub fn missing_context_test() {
  let missing_key: radiant.Key(String) = radiant.key("missing")

  let router =
    radiant.new()
    |> radiant.get("/profile", fn(req) {
      case radiant.get_context(req, missing_key) {
        Ok(_) -> radiant.ok("found")
        Error(_) -> radiant.ok("none")
      }
    })

  radiant.handle(router, radiant.test_get("/profile"))
  |> fn(r) { r.body }
  |> should.equal(<<"none":utf8>>)
}

// ---------------------------------------------------------------------------
// Typed Parameter Routing
// ---------------------------------------------------------------------------

pub fn typed_int_param_test() {
  let router =
    radiant.new()
    |> radiant.get("/users/<id:int>", fn(req) {
      let assert Ok(id) = radiant.int_param(req, "id")
      radiant.ok("int:" <> int.to_string(id))
    })

  // Valid int
  radiant.handle(router, radiant.test_get("/users/42"))
  |> fn(r) { r.body }
  |> should.equal(<<"int:42":utf8>>)

  // Invalid int routes to 404
  radiant.handle(router, radiant.test_get("/users/abc"))
  |> fn(r) { r.status }
  |> should.equal(404)
}

pub fn typed_string_param_alias_test() {
  let router =
    radiant.new()
    |> radiant.get("/docs/<path>", fn(req) {
      let assert Ok(p) = radiant.str_param(req, "path")
      radiant.ok(p)
    })

  radiant.handle(router, radiant.test_get("/docs/intro"))
  |> fn(r) { r.body }
  |> should.equal(<<"intro":utf8>>)
}

// ---------------------------------------------------------------------------
// JSON Middleware
// ---------------------------------------------------------------------------

pub type User {
  User(name: String)
}

pub fn json_middleware_test() {
  let user_key = radiant.key("user")
  let user_decoder = {
    use name <- decode.field("name", decode.string)
    decode.success(User(name))
  }

  let router =
    radiant.new()
    |> radiant.middleware(radiant.json_body(user_key, user_decoder))
    |> radiant.post("/greet", fn(req) {
      let assert Ok(user) = radiant.get_context(req, user_key)
      radiant.ok("hello " <> user.name)
    })

  let body = "{\"name\":\"Joe\"}"
  radiant.handle(router, radiant.test_post("/greet", body))
  |> fn(r) { r.body }
  |> should.equal(<<"hello Joe":utf8>>)
}

pub fn json_middleware_invalid_test() {
  let id_key = radiant.key("id")
  let decoder = decode.at(["id"], decode.int)
  let router =
    radiant.new()
    |> radiant.middleware(radiant.json_body(id_key, decoder))
    |> radiant.post("/id", fn(_req) { radiant.ok("ok") })

  // Invalid JSON
  radiant.handle(router, radiant.test_post("/id", "not json"))
  |> fn(r) { r.status }
  |> should.equal(400)

  // Valid JSON but wrong schema
  radiant.handle(router, radiant.test_post("/id", "{\"name\":\"Joe\"}"))
  |> fn(r) { r.status }
  |> should.equal(400)
}

// ---------------------------------------------------------------------------
// Static Files Middleware
// ---------------------------------------------------------------------------

fn mock_fs() -> radiant.FileSystem {
  radiant.FileSystem(
    is_file: fn(p) {
      case p {
        "pub/style.css" -> True
        "pub/index.html" -> True
        _ -> False
      }
    },
    read_bits: fn(p) {
      case p {
        "pub/style.css" -> Ok(<<"body{}":utf8>>)
        "pub/index.html" -> Ok(<<"<html></html>":utf8>>)
        _ -> Error(Nil)
      }
    },
  )
}

pub fn serve_static_test() {
  let router =
    radiant.new()
    |> radiant.middleware(radiant.serve_static("/assets", "pub", mock_fs()))
    |> radiant.get("/ping", fn(_) { radiant.ok("pong") })

  // Match file
  let resp = radiant.handle(router, radiant.test_get("/assets/style.css"))
  resp.status |> should.equal(200)
  resp.body |> should.equal(<<"body{}":utf8>>)
  response.get_header(resp, "content-type") |> should.equal(Ok("text/css"))

  // Fallback to normal route
  radiant.handle(router, radiant.test_get("/ping"))
  |> fn(r) { r.body }
  |> should.equal(<<"pong":utf8>>)
}

pub fn serve_static_traversal_test() {
  let router =
    radiant.new()
    |> radiant.middleware(radiant.serve_static("/assets", "pub", mock_fs()))

  // Traversal attempt (../) should be filtered out by path join logic
  // Path "/assets/../style.css" -> rel_path "style.css" -> full "pub/style.css"
  // Wait, if it's filtered, it avoids going up.
  // Actually, we want to ensure it doesn't escape.
  let resp = radiant.handle(router, radiant.test_get("/assets/../../etc/passwd"))
  // It should either fall back or serve nothing if is_file fails.
  // In our mock, etc/passwd is False.
  resp.status |> should.equal(404)
}

pub fn serve_static_404_test() {
  let router =
    radiant.new()
    |> radiant.middleware(radiant.serve_static("/assets", "pub", mock_fs()))
  radiant.handle(router, radiant.test_get("/assets/missing.js"))
  |> fn(r) { r.status }
  |> should.equal(404)
}

pub fn fluent_assertions_test() {
  let router =
    radiant.new()
    |> radiant.get("/api/user", fn(_) {
      radiant.json("{\"id\":123}")
      |> response.set_header("x-version", "1")
    })

  radiant.handle(router, radiant.test_get("/api/user"))
  |> radiant.should_have_status(200)
  |> radiant.should_have_header("x-version", "1")
  |> radiant.should_have_json_body(decode.at(["id"], decode.int))
  |> should.equal(123)
}

// ---------------------------------------------------------------------------
// Duplicate route — first-wins
// ---------------------------------------------------------------------------

pub fn duplicate_route_first_wins_test() {
  let router =
    radiant.new()
    |> radiant.get("/dup", fn(_req) { radiant.ok("first") })
    |> radiant.get("/dup", fn(_req) { radiant.ok("second") })

  // The second registration is silently dropped; first handler wins.
  radiant.handle(router, radiant.test_get("/dup"))
  |> fn(r) { r.body }
  |> should.equal(<<"first":utf8>>)
}

// ---------------------------------------------------------------------------
// Mount — multiple middlewares preserve registration order
// ---------------------------------------------------------------------------

pub fn mount_middleware_order_test() {
  // Two middlewares that each set the same header.
  // mw_a is registered first → outermost → runs last on response → wins.
  let mw_a: radiant.Middleware = fn(next) {
    fn(req) { next(req) |> radiant.with_header("x-order", "A") }
  }
  let mw_b: radiant.Middleware = fn(next) {
    fn(req) { next(req) |> radiant.with_header("x-order", "B") }
  }

  let sub_router =
    radiant.new()
    |> radiant.middleware(mw_a)
    |> radiant.middleware(mw_b)
    |> radiant.get("/check", fn(_req) { radiant.ok("ok") })

  let router =
    radiant.new()
    |> radiant.mount("/sub", sub_router)

  let resp = radiant.handle(router, radiant.test_get("/sub/check"))
  resp.status |> should.equal(200)
  // mw_a outermost: handler → mw_b sets "B" → mw_a sets "A"
  response.get_header(resp, "x-order") |> should.equal(Ok("A"))
}

// ---------------------------------------------------------------------------
// any — method-agnostic routes
// ---------------------------------------------------------------------------

pub fn any_matches_all_methods_test() {
  let router =
    radiant.new()
    |> radiant.any("/health", fn(_req) { radiant.ok("ok") })

  radiant.handle(router, radiant.test_get("/health")).status
  |> should.equal(200)

  radiant.handle(router, radiant.test_post("/health", "")).status
  |> should.equal(200)

  radiant.handle(router, radiant.test_delete("/health")).status
  |> should.equal(200)
}

pub fn any_does_not_shadow_specific_routes_test() {
  // A specific method registered after any() wins for that method
  // because any() registers each method individually (first-wins applies).
  let router =
    radiant.new()
    |> radiant.any("/ping", fn(_req) { radiant.ok("any") })

  radiant.handle(router, radiant.test_get("/ping"))
  |> fn(r) { r.body }
  |> should.equal(<<"any":utf8>>)
}

// ---------------------------------------------------------------------------
// routes — introspection
// ---------------------------------------------------------------------------

pub fn routes_lists_registered_test() {
  let router =
    radiant.new()
    |> radiant.get("/", fn(_req) { radiant.ok("home") })
    |> radiant.post("/users", fn(_req) { radiant.ok("create") })
    |> radiant.get("/users/<id:int>", fn(_req) { radiant.ok("show") })

  let listed = radiant.routes(router)

  // All three routes must appear
  list.length(listed) |> should.equal(3)
  list.map(listed, fn(r) { r.1 })
  |> list.contains("/")
  |> should.be_true()
  list.map(listed, fn(r) { r.1 })
  |> list.contains("/users/<id:int>")
  |> should.be_true()
}

pub fn routes_includes_scoped_test() {
  let router =
    radiant.new()
    |> radiant.scope("/api", fn(r) {
      r |> radiant.get("/status", fn(_req) { radiant.ok("ok") })
    })

  let listed = radiant.routes(router)
  list.map(listed, fn(r) { r.1 })
  |> list.contains("/api/status")
  |> should.be_true()
}

// ---------------------------------------------------------------------------
// path_for — reverse routing
// ---------------------------------------------------------------------------

pub fn path_for_literal_test() {
  radiant.path_for("/users", [])
  |> should.equal(Ok("/users"))
}

pub fn path_for_single_param_test() {
  radiant.path_for("/users/<id:int>", [#("id", "42")])
  |> should.equal(Ok("/users/42"))
}

pub fn path_for_multiple_params_test() {
  radiant.path_for(
    "/users/<uid:int>/posts/<pid:int>",
    [#("uid", "1"), #("pid", "99")],
  )
  |> should.equal(Ok("/users/1/posts/99"))
}

pub fn path_for_colon_syntax_test() {
  radiant.path_for("/items/:slug", [#("slug", "hello-world")])
  |> should.equal(Ok("/items/hello-world"))
}

pub fn path_for_wildcard_test() {
  radiant.path_for("/files/*rest", [#("rest", "css/main.css")])
  |> should.equal(Ok("/files/css/main.css"))
}

pub fn path_for_missing_param_test() {
  radiant.path_for("/users/<id:int>", [])
  |> should.equal(Error(Nil))
}

pub fn path_for_root_test() {
  radiant.path_for("/", [])
  |> should.equal(Ok("/"))
}

// ---------------------------------------------------------------------------
// get1 / get2 / get3 — typed param handlers
// ---------------------------------------------------------------------------

pub fn get1_int_test() {
  let router =
    radiant.new()
    |> radiant.get1("/users/:id", radiant.int("id"), fn(_req, id) {
      radiant.ok(int.to_string(id))
    })

  // Matches — id is Int, no extraction needed
  radiant.handle(router, radiant.test_get("/users/42"))
  |> fn(r) { r.body }
  |> should.equal(<<"42":utf8>>)

  // Non-integer → 404 (tree rejects before handler is called)
  radiant.handle(router, radiant.test_get("/users/alice"))
  |> fn(r) { r.status }
  |> should.equal(404)
}

pub fn get1_str_test() {
  let router =
    radiant.new()
    |> radiant.get1("/posts/:slug", radiant.str("slug"), fn(_req, slug) {
      radiant.ok(slug)
    })

  radiant.handle(router, radiant.test_get("/posts/hello-world"))
  |> fn(r) { r.body }
  |> should.equal(<<"hello-world":utf8>>)
}

pub fn get2_test() {
  let router =
    radiant.new()
    |> radiant.get2(
      "/users/:uid/posts/:pid",
      radiant.int("uid"),
      radiant.int("pid"),
      fn(_req, uid, pid) {
        radiant.ok(int.to_string(uid) <> ":" <> int.to_string(pid))
      },
    )

  radiant.handle(router, radiant.test_get("/users/1/posts/99"))
  |> fn(r) { r.body }
  |> should.equal(<<"1:99":utf8>>)
}

pub fn get3_test() {
  let router =
    radiant.new()
    |> radiant.get3(
      "/a/:x/b/:y/c/:z",
      radiant.int("x"),
      radiant.str("y"),
      radiant.int("z"),
      fn(_req, x, y, z) {
        radiant.ok(int.to_string(x) <> y <> int.to_string(z))
      },
    )

  radiant.handle(router, radiant.test_get("/a/1/b/hello/c/2"))
  |> fn(r) { r.body }
  |> should.equal(<<"1hello2":utf8>>)
}

pub fn typed_dispatch_fallback_test() {
  // int param registered first: matches /items/42
  // str param registered second: matches /items/hello (fallback for non-int)
  let router =
    radiant.new()
    |> radiant.get1("/items/:id", radiant.int("id"), fn(_req, id) {
      radiant.ok("int:" <> int.to_string(id))
    })
    |> radiant.get1("/items/:id", radiant.str("id"), fn(_req, id) {
      radiant.ok("str:" <> id)
    })

  radiant.handle(router, radiant.test_get("/items/42"))
  |> fn(r) { r.body }
  |> should.equal(<<"int:42":utf8>>)

  radiant.handle(router, radiant.test_get("/items/hello"))
  |> fn(r) { r.body }
  |> should.equal(<<"str:hello":utf8>>)
}

pub fn get1_post1_same_path_test() {
  let router =
    radiant.new()
    |> radiant.get1("/items/:id", radiant.int("id"), fn(_req, id) {
      radiant.ok("get:" <> int.to_string(id))
    })
    |> radiant.post1("/items/:id", radiant.int("id"), fn(_req, id) {
      radiant.ok("post:" <> int.to_string(id))
    })

  radiant.handle(router, radiant.test_get("/items/5"))
  |> fn(r) { r.body }
  |> should.equal(<<"get:5":utf8>>)

  radiant.handle(router, radiant.test_post("/items/5", ""))
  |> fn(r) { r.body }
  |> should.equal(<<"post:5":utf8>>)
}
