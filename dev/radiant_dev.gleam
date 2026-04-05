import gleam/bytes_tree
import gleam/erlang/process
import gleam/http
import gleam/http/response
import gleam/int
import gleam/list
import mist
import radiant
import woof

pub fn main() {
  woof.configure(woof.Config(
    level: woof.Debug,
    format: woof.Text,
    colors: woof.Always,
  ))

  let router = demo_router()

  // Log all registered routes at startup
  list.each(radiant.routes(router), fn(r) {
    let #(method, path) = r
    woof.info("route registered", [
      woof.field("method", http.method_to_string(method)),
      woof.field("path", path),
    ])
  })

  let assert Ok(_) =
    mist.new(fn(req) {
      let resp = radiant.handle(router, req)
      response.set_body(resp, mist.Bytes(bytes_tree.from_bit_array(resp.body)))
    })
    |> mist.read_request_body(
      bytes_limit: 4_194_304,
      failure_response: response.new(413)
        |> response.set_body(
          mist.Bytes(bytes_tree.from_bit_array(<<"Request too large":utf8>>)),
        ),
    )
    |> mist.port(4000)
    |> mist.after_start(fn(port, _scheme, _ip) {
      woof.info("Radiant dev server started", [
        woof.field("url", "http://localhost:" <> int.to_string(port)),
      ])
    })
    |> mist.start()

  process.sleep_forever()
}

fn demo_router() -> radiant.Router {
  radiant.new()
  // ── Middleware ───────────────────────────────────────────────────────────
  |> radiant.middleware(radiant.cors(radiant.default_cors()))
  |> radiant.middleware(
    radiant.rescue(fn(_err) { radiant.internal_server_error() }),
  )
  |> radiant.middleware(fn(next) {
    fn(req) {
      woof.info(
        http.method_to_string(radiant.method(req))
          <> " "
          <> radiant.req_path(req),
        [],
      )
      next(req)
    }
  })
  // ── Root ─────────────────────────────────────────────────────────────────
  |> radiant.get("/", fn(_req) {
    radiant.html("<h1>Radiant</h1><p>Type-safe HTTP router for Gleam.</p>")
  })
  // ── Literal beats capture: /users/me always wins over /users/<id:int> ───
  |> radiant.get("/users/me", fn(_req) {
    radiant.json("{\"id\":0,\"name\":\"current user\"}")
  })
  // ── Typed route: handler receives Int directly, no int_param needed ──────
  |> radiant.get1("/users/<id:int>", radiant.int("id"), fn(_req, id) {
    radiant.json(
      "{\"id\":"
      <> int.to_string(id)
      <> ",\"name\":\"user_"
      <> int.to_string(id)
      <> "\"}",
    )
  })
  // ── Typed route: String param ─────────────────────────────────────────────
  |> radiant.get1("/hello/<name:string>", radiant.str("name"), fn(_req, name) {
    radiant.ok("Hello, " <> name <> "!")
  })
  // ── Wildcard ──────────────────────────────────────────────────────────────
  |> radiant.get("/files/*path", fn(req) {
    case radiant.str_param(req, "path") {
      Ok(path) -> radiant.ok("Requested file: " <> path)
      Error(Nil) -> radiant.bad_request()
    }
  })
  // ── Query params ──────────────────────────────────────────────────────────
  |> radiant.get("/search", fn(req) {
    case radiant.query(req, "q") {
      Ok(q) -> radiant.ok("Results for: " <> q)
      Error(Nil) -> radiant.ok("No query provided")
    }
  })
  // ── Reverse routing demo ──────────────────────────────────────────────────
  |> radiant.get("/redirect-demo", fn(_req) {
    case radiant.path_for("/users/<id:int>", [#("id", "99")]) {
      Ok(url) -> radiant.redirect(url)
      Error(Nil) -> radiant.internal_server_error()
    }
  })
  // ── Scope ─────────────────────────────────────────────────────────────────
  |> radiant.scope("/api", fn(r) {
    r
    |> radiant.post("/echo", fn(req) {
      case radiant.text_body(req) {
        Ok(text) ->
          radiant.json("{\"echo\":\"" <> text <> "\"}")
          |> radiant.with_header("x-echoed", "true")
        Error(Nil) -> radiant.bad_request()
      }
    })
    // 401 / 403 demo
    |> radiant.get("/secret", fn(req) {
      case radiant.header(req, "authorization") {
        Error(Nil) -> radiant.unauthorized()
        Ok("Bearer admin") -> radiant.json("{\"secret\":\"42\"}")
        Ok(_) -> radiant.forbidden()
      }
    })
  })
  |> radiant.fallback(fn(req) {
    radiant.response(404, "Not found: " <> radiant.req_path(req))
  })
}
