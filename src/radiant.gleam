//// A trie-based HTTP router for Gleam on BEAM.
//// One import, no sub-modules. See the [README](https://hexdocs.pm/radiant/) for examples.

import exception
import gleam/bit_array
import gleam/dict.{type Dict}
import gleam/dynamic
import gleam/dynamic/decode
import gleam/http.{type Method, Delete, Get, Patch, Post, Put}
import gleam/http/request.{type Request, Request}
import gleam/http/response.{type Response, Response}
import gleam/float
import gleam/int
import gleam/json as gjson
import gleam/list
import gleam/option.{None, Some}
import gleam/result
import gleam/string
import gleam/uri
import radiant/internal/path as ipath
import radiant/internal/tree

// ---------------------------------------------------------------------------
// Types
// ---------------------------------------------------------------------------

/// An opaque router that maps HTTP method + path pattern to handlers.
pub opaque type Router {
  Router(
    tree: tree.Node(fn(Req) -> Response(BitArray)),
    fallback: fn(Req) -> Response(BitArray),
    middlewares: List(Middleware),
  )
}

/// A middleware transforms a handler into a new handler.
/// Use this for cross-cutting concerns: logging, CORS, timing, auth.
pub type Middleware =
  fn(fn(Req) -> Response(BitArray)) -> fn(Req) -> Response(BitArray)

/// A swappable interface for file system operations.
/// This allows using `simplifile` now and switching to other libraries like `fio` later.
pub type FileSystem {
  FileSystem(
    read_bits: fn(String) -> Result(BitArray, Nil),
    is_file: fn(String) -> Bool,
  )
}

/// An opaque request wrapper carrying the original request, extracted
/// path parameters, and a typed context for middlewares to pass data.
pub opaque type Req {
  Req(
    request: Request(BitArray),
    params: Dict(String, String),
    context: Dict(String, dynamic.Dynamic),
  )
}

/// A typed key for the request context. The phantom type `a` ensures that
/// the value retrieved from the context always matches the type stored.
///
/// Define keys as module-level constants for maximum safety:
///
/// ```gleam
/// pub const user_key: radiant.Key(User) = radiant.key("user")
/// ```
pub opaque type Key(a) {
  Key(String)
}

/// A typed path parameter for use with `get1`, `get2`, `get3`, etc.
/// Carries the parameter name, its parse function, and the type constraint
/// used by the routing tree.
///
/// Create with `radiant.int(name)` or `radiant.str(name)`.
pub opaque type Param(a) {
  Param(
    name: String,
    parse: fn(String) -> Result(a, Nil),
    ptype: ipath.ParamType,
    to_string: fn(a) -> String,
  )
}

// ---------------------------------------------------------------------------
// Router
// ---------------------------------------------------------------------------

/// A `Param(Int)` that matches only integer path segments.
/// For use with `get1`, `get2`, `get3`, etc.
///
/// ```gleam
/// router |> radiant.get1("/users/:id", radiant.int("id"), fn(req, id) {
///   radiant.ok(int.to_string(id))  // id: Int, guaranteed
/// })
/// ```
pub fn int(name: String) -> Param(Int) {
  Param(
    name: name,
    parse: int.parse,
    ptype: ipath.IntT,
    to_string: int.to_string,
  )
}

/// A `Param(String)` that matches any path segment.
/// For use with `get1`, `get2`, `get3`, etc.
///
/// ```gleam
/// router |> radiant.get1("/posts/:slug", radiant.str("slug"), fn(req, slug) {
///   radiant.ok(slug)  // slug: String, no extraction needed
/// })
/// ```
pub fn str(name: String) -> Param(String) {
  Param(
    name: name,
    parse: fn(s) { Ok(s) },
    ptype: ipath.StringT,
    to_string: fn(s) { s },
  )
}

/// Create a typed context key. Pair with `set_context` and `get_context`
/// for type-safe request context passing through middlewares.
///
/// ```gleam
/// pub const user_key: radiant.Key(User) = radiant.key("user")
///
/// // In middleware:
/// radiant.set_context(req, user_key, authenticated_user)
///
/// // In handler:
/// let assert Ok(user) = radiant.get_context(req, user_key)
/// ```
pub fn key(name: String) -> Key(a) {
  Key(name)
}

/// Create an empty router with a default 404 fallback.
pub fn new() -> Router {
  Router(tree: tree.new(), fallback: fn(_req) { not_found() }, middlewares: [])
}

/// Set a custom fallback handler for unmatched requests.
pub fn fallback(
  router: Router,
  handler: fn(Req) -> Response(BitArray),
) -> Router {
  Router(..router, fallback: handler)
}

/// Add a middleware that wraps every request through this router.
/// Middlewares are applied in the order they are added (first added = outermost).
///
/// ```gleam
/// radiant.new()
/// |> radiant.middleware(radiant.log(fn(msg) { io.println(msg) }))
/// |> radiant.middleware(radiant.cors(radiant.default_cors()))
/// |> radiant.get("/", handler)
/// ```
pub fn middleware(router: Router, mw: Middleware) -> Router {
  Router(..router, middlewares: [mw, ..router.middlewares])
}

/// Register a GET route.
pub fn get(
  router: Router,
  pattern: String,
  handler: fn(Req) -> Response(BitArray),
) -> Router {
  add_route(router, Get, pattern, handler)
}

/// Register a POST route.
pub fn post(
  router: Router,
  pattern: String,
  handler: fn(Req) -> Response(BitArray),
) -> Router {
  add_route(router, Post, pattern, handler)
}

/// Register a PUT route.
pub fn put(
  router: Router,
  pattern: String,
  handler: fn(Req) -> Response(BitArray),
) -> Router {
  add_route(router, Put, pattern, handler)
}

/// Register a PATCH route.
pub fn patch(
  router: Router,
  pattern: String,
  handler: fn(Req) -> Response(BitArray),
) -> Router {
  add_route(router, Patch, pattern, handler)
}

/// Register a DELETE route.
pub fn delete(
  router: Router,
  pattern: String,
  handler: fn(Req) -> Response(BitArray),
) -> Router {
  add_route(router, Delete, pattern, handler)
}

/// Register an OPTIONS route.
/// Useful for custom preflight handling when the `cors` middleware is not used.
pub fn options(
  router: Router,
  pattern: String,
  handler: fn(Req) -> Response(BitArray),
) -> Router {
  add_route(router, http.Options, pattern, handler)
}

// ---------------------------------------------------------------------------
// Typed route registration (get1 / get2 / get3 and equivalents)
// ---------------------------------------------------------------------------

/// Register a GET route with one typed path parameter.
/// The handler receives the extracted value directly — no manual extraction.
///
/// ```gleam
/// router |> radiant.get1("/users/:id", radiant.int("id"), fn(req, id) {
///   radiant.ok("User " <> int.to_string(id))
/// })
/// ```
pub fn get1(
  router: Router,
  pattern: String,
  p1: Param(a),
  handler: fn(Req, a) -> Response(BitArray),
) -> Router {
  typed1(router, Get, pattern, p1, handler)
}

pub fn post1(
  router: Router,
  pattern: String,
  p1: Param(a),
  handler: fn(Req, a) -> Response(BitArray),
) -> Router {
  typed1(router, Post, pattern, p1, handler)
}

pub fn put1(
  router: Router,
  pattern: String,
  p1: Param(a),
  handler: fn(Req, a) -> Response(BitArray),
) -> Router {
  typed1(router, Put, pattern, p1, handler)
}

pub fn patch1(
  router: Router,
  pattern: String,
  p1: Param(a),
  handler: fn(Req, a) -> Response(BitArray),
) -> Router {
  typed1(router, Patch, pattern, p1, handler)
}

pub fn delete1(
  router: Router,
  pattern: String,
  p1: Param(a),
  handler: fn(Req, a) -> Response(BitArray),
) -> Router {
  typed1(router, Delete, pattern, p1, handler)
}

/// Register a GET route with two typed path parameters.
///
/// ```gleam
/// router |> radiant.get2(
///   "/users/:uid/posts/:pid",
///   radiant.int("uid"), radiant.int("pid"),
///   fn(req, uid, pid) { radiant.ok(int.to_string(uid) <> "/" <> int.to_string(pid)) },
/// )
/// ```
pub fn get2(
  router: Router,
  pattern: String,
  p1: Param(a),
  p2: Param(b),
  handler: fn(Req, a, b) -> Response(BitArray),
) -> Router {
  typed2(router, Get, pattern, p1, p2, handler)
}

pub fn post2(
  router: Router,
  pattern: String,
  p1: Param(a),
  p2: Param(b),
  handler: fn(Req, a, b) -> Response(BitArray),
) -> Router {
  typed2(router, Post, pattern, p1, p2, handler)
}

pub fn put2(
  router: Router,
  pattern: String,
  p1: Param(a),
  p2: Param(b),
  handler: fn(Req, a, b) -> Response(BitArray),
) -> Router {
  typed2(router, Put, pattern, p1, p2, handler)
}

pub fn patch2(
  router: Router,
  pattern: String,
  p1: Param(a),
  p2: Param(b),
  handler: fn(Req, a, b) -> Response(BitArray),
) -> Router {
  typed2(router, Patch, pattern, p1, p2, handler)
}

pub fn delete2(
  router: Router,
  pattern: String,
  p1: Param(a),
  p2: Param(b),
  handler: fn(Req, a, b) -> Response(BitArray),
) -> Router {
  typed2(router, Delete, pattern, p1, p2, handler)
}

/// Register a GET route with three typed path parameters.
pub fn get3(
  router: Router,
  pattern: String,
  p1: Param(a),
  p2: Param(b),
  p3: Param(c),
  handler: fn(Req, a, b, c) -> Response(BitArray),
) -> Router {
  typed3(router, Get, pattern, p1, p2, p3, handler)
}

pub fn post3(
  router: Router,
  pattern: String,
  p1: Param(a),
  p2: Param(b),
  p3: Param(c),
  handler: fn(Req, a, b, c) -> Response(BitArray),
) -> Router {
  typed3(router, Post, pattern, p1, p2, p3, handler)
}

pub fn put3(
  router: Router,
  pattern: String,
  p1: Param(a),
  p2: Param(b),
  p3: Param(c),
  handler: fn(Req, a, b, c) -> Response(BitArray),
) -> Router {
  typed3(router, Put, pattern, p1, p2, p3, handler)
}

pub fn patch3(
  router: Router,
  pattern: String,
  p1: Param(a),
  p2: Param(b),
  p3: Param(c),
  handler: fn(Req, a, b, c) -> Response(BitArray),
) -> Router {
  typed3(router, Patch, pattern, p1, p2, p3, handler)
}

pub fn delete3(
  router: Router,
  pattern: String,
  p1: Param(a),
  p2: Param(b),
  p3: Param(c),
  handler: fn(Req, a, b, c) -> Response(BitArray),
) -> Router {
  typed3(router, Delete, pattern, p1, p2, p3, handler)
}

/// Register a GET route with four typed path parameters.
pub fn get4(
  router: Router,
  pattern: String,
  p1: Param(a),
  p2: Param(b),
  p3: Param(c),
  p4: Param(d),
  handler: fn(Req, a, b, c, d) -> Response(BitArray),
) -> Router {
  typed4(router, Get, pattern, p1, p2, p3, p4, handler)
}

pub fn post4(
  router: Router,
  pattern: String,
  p1: Param(a),
  p2: Param(b),
  p3: Param(c),
  p4: Param(d),
  handler: fn(Req, a, b, c, d) -> Response(BitArray),
) -> Router {
  typed4(router, Post, pattern, p1, p2, p3, p4, handler)
}

pub fn put4(
  router: Router,
  pattern: String,
  p1: Param(a),
  p2: Param(b),
  p3: Param(c),
  p4: Param(d),
  handler: fn(Req, a, b, c, d) -> Response(BitArray),
) -> Router {
  typed4(router, Put, pattern, p1, p2, p3, p4, handler)
}

pub fn patch4(
  router: Router,
  pattern: String,
  p1: Param(a),
  p2: Param(b),
  p3: Param(c),
  p4: Param(d),
  handler: fn(Req, a, b, c, d) -> Response(BitArray),
) -> Router {
  typed4(router, Patch, pattern, p1, p2, p3, p4, handler)
}

pub fn delete4(
  router: Router,
  pattern: String,
  p1: Param(a),
  p2: Param(b),
  p3: Param(c),
  p4: Param(d),
  handler: fn(Req, a, b, c, d) -> Response(BitArray),
) -> Router {
  typed4(router, Delete, pattern, p1, p2, p3, p4, handler)
}

/// Register a GET route with five typed path parameters.
pub fn get5(
  router: Router,
  pattern: String,
  p1: Param(a),
  p2: Param(b),
  p3: Param(c),
  p4: Param(d),
  p5: Param(e),
  handler: fn(Req, a, b, c, d, e) -> Response(BitArray),
) -> Router {
  typed5(router, Get, pattern, p1, p2, p3, p4, p5, handler)
}

pub fn post5(
  router: Router,
  pattern: String,
  p1: Param(a),
  p2: Param(b),
  p3: Param(c),
  p4: Param(d),
  p5: Param(e),
  handler: fn(Req, a, b, c, d, e) -> Response(BitArray),
) -> Router {
  typed5(router, Post, pattern, p1, p2, p3, p4, p5, handler)
}

pub fn put5(
  router: Router,
  pattern: String,
  p1: Param(a),
  p2: Param(b),
  p3: Param(c),
  p4: Param(d),
  p5: Param(e),
  handler: fn(Req, a, b, c, d, e) -> Response(BitArray),
) -> Router {
  typed5(router, Put, pattern, p1, p2, p3, p4, p5, handler)
}

pub fn patch5(
  router: Router,
  pattern: String,
  p1: Param(a),
  p2: Param(b),
  p3: Param(c),
  p4: Param(d),
  p5: Param(e),
  handler: fn(Req, a, b, c, d, e) -> Response(BitArray),
) -> Router {
  typed5(router, Patch, pattern, p1, p2, p3, p4, p5, handler)
}

pub fn delete5(
  router: Router,
  pattern: String,
  p1: Param(a),
  p2: Param(b),
  p3: Param(c),
  p4: Param(d),
  p5: Param(e),
  handler: fn(Req, a, b, c, d, e) -> Response(BitArray),
) -> Router {
  typed5(router, Delete, pattern, p1, p2, p3, p4, p5, handler)
}

/// Register a GET route with six typed path parameters.
pub fn get6(
  router: Router,
  pattern: String,
  p1: Param(a),
  p2: Param(b),
  p3: Param(c),
  p4: Param(d),
  p5: Param(e),
  p6: Param(f),
  handler: fn(Req, a, b, c, d, e, f) -> Response(BitArray),
) -> Router {
  typed6(router, Get, pattern, p1, p2, p3, p4, p5, p6, handler)
}

pub fn post6(
  router: Router,
  pattern: String,
  p1: Param(a),
  p2: Param(b),
  p3: Param(c),
  p4: Param(d),
  p5: Param(e),
  p6: Param(f),
  handler: fn(Req, a, b, c, d, e, f) -> Response(BitArray),
) -> Router {
  typed6(router, Post, pattern, p1, p2, p3, p4, p5, p6, handler)
}

pub fn put6(
  router: Router,
  pattern: String,
  p1: Param(a),
  p2: Param(b),
  p3: Param(c),
  p4: Param(d),
  p5: Param(e),
  p6: Param(f),
  handler: fn(Req, a, b, c, d, e, f) -> Response(BitArray),
) -> Router {
  typed6(router, Put, pattern, p1, p2, p3, p4, p5, p6, handler)
}

pub fn patch6(
  router: Router,
  pattern: String,
  p1: Param(a),
  p2: Param(b),
  p3: Param(c),
  p4: Param(d),
  p5: Param(e),
  p6: Param(f),
  handler: fn(Req, a, b, c, d, e, f) -> Response(BitArray),
) -> Router {
  typed6(router, Patch, pattern, p1, p2, p3, p4, p5, p6, handler)
}

pub fn delete6(
  router: Router,
  pattern: String,
  p1: Param(a),
  p2: Param(b),
  p3: Param(c),
  p4: Param(d),
  p5: Param(e),
  p6: Param(f),
  handler: fn(Req, a, b, c, d, e, f) -> Response(BitArray),
) -> Router {
  typed6(router, Delete, pattern, p1, p2, p3, p4, p5, p6, handler)
}

/// Group routes under a common path prefix.
///
/// ```gleam
/// radiant.new()
/// |> radiant.scope("/api/v1", fn(r) {
///   r
///   |> radiant.get("/users", list_users)
///   |> radiant.get("/users/:id", show_user)
/// })
/// ```
pub fn scope(
  router: Router,
  prefix: String,
  builder: fn(Router) -> Router,
) -> Router {
  let scoped = builder(new())
  let prefix_segs = ipath.parse(prefix)
  let sub_routes = tree.to_routes(scoped.tree)

  list.fold(sub_routes, router, fn(acc_router, r) {
    let #(method, segments, handler) = r
    let full_segments = list.append(prefix_segs, segments)
    let new_tree = tree.insert(acc_router.tree, method, full_segments, handler)
    Router(..acc_router, tree: new_tree)
  })
}

/// Mount a complete sub-router at a given path prefix.
///
/// Unlike `scope`, which builds routes in the same context, `mount` allows
/// you to define independent routers (with their own middlewares) and
/// attach them to a parent router.
///
/// Note: The sub-router's fallback handler is ignored. Unmatched requests
/// will fall through to the parent router's fallback.
pub fn mount(router: Router, prefix: String, sub_router: Router) -> Router {
  let prefix_segs = ipath.parse(prefix)
  let sub_routes = tree.to_routes(sub_router.tree)

  list.fold(sub_routes, router, fn(acc_router, r) {
    let #(method, segments, handler) = r

    // Apply sub_router's middlewares to the handler (stored newest-first)
    let with_middlewares =
      list.fold(sub_router.middlewares, handler, fn(h, mw) { mw(h) })

    let full_segments = list.append(prefix_segs, segments)
    let new_tree =
      tree.insert(acc_router.tree, method, full_segments, with_middlewares)
    Router(..acc_router, tree: new_tree)
  })
}

/// Dispatch a raw HTTP request through the router, returning a response.
///
/// This is the main entry point connecting radiant to any HTTP server.
/// Middlewares are applied in registration order (first added = outermost).
///
/// If the path matches a route but the method does not, returns 405 Method
/// Not Allowed with an `allow` header listing the accepted methods.
pub fn handle(router: Router, req: Request(BitArray)) -> Response(BitArray) {
  let dispatch = fn(r: Req) -> Response(BitArray) {
    let segments = ipath.split(r.request.path)
    case tree.match(router.tree, r.request.method, segments) {
      Ok(#(handler, params)) -> handler(Req(..r, params: params))
      Error(Nil) -> {
        // HEAD falls through to GET per HTTP/1.1 spec (RFC 9110 §9.3.2).
        // Run the GET handler and strip the response body.
        let head_result = case r.request.method {
          http.Head ->
            case tree.match(router.tree, Get, segments) {
              Ok(#(handler, params)) ->
                Ok(handler(
                  Req(
                    ..r,
                    params: params,
                    request: Request(..r.request, method: Get),
                  ),
                ))
              Error(_) -> Error(Nil)
            }
          _ -> Error(Nil)
        }
        case head_result {
          Ok(resp) -> Response(..resp, body: <<>>)
          Error(_) -> {
            let allowed = tree.allowed_methods(router.tree, segments)
            case allowed {
              [] -> router.fallback(r)
              _ ->
                method_not_allowed(
                  allowed
                  |> list.map(http.method_to_string)
                  |> string.join(", "),
                )
            }
          }
        }
      }
    }
  }
  // middlewares is stored newest-first; fold left so the first-added
  // ends up as the outermost wrapper (executes first).
  let final_handler =
    list.fold(router.middlewares, dispatch, fn(handler, mw) { mw(handler) })
  final_handler(Req(request: req, params: dict.new(), context: dict.new()))
}

/// Like `handle`, but accepts a request with any body type plus a separately
/// read `BitArray` body. Useful for Wisp integration where the body is read
/// through `wisp.require_bit_array_body` before routing.
///
/// ```gleam
/// use body <- wisp.require_bit_array_body(req)
/// radiant.handle_with(router, req, body)
/// ```
pub fn handle_with(
  router: Router,
  req: Request(anything),
  body: BitArray,
) -> Response(BitArray) {
  handle(router, request.set_body(req, body))
}

/// Register the same handler for all standard HTTP methods on a pattern.
/// Useful for health check endpoints or method-agnostic catch-alls.
///
/// ```gleam
/// radiant.new()
/// |> radiant.any("/health", fn(_req) { radiant.ok("ok") })
/// ```
pub fn any(
  router: Router,
  pattern: String,
  handler: fn(Req) -> Response(BitArray),
) -> Router {
  [Get, Post, Put, Patch, Delete]
  |> list.fold(router, fn(r, m) { add_route(r, m, pattern, handler) })
}

/// Return all registered routes as `(method, pattern)` pairs.
///
/// Useful for logging the route table at startup, contract tests,
/// or building documentation from a live router.
///
/// ```gleam
/// radiant.routes(router)
/// // → [#(http.Get, "/"), #(http.Get, "/users/<id:int>"), ...]
/// ```
pub fn routes(router: Router) -> List(#(Method, String)) {
  tree.to_routes(router.tree)
  |> list.map(fn(r) {
    let #(method, segments, _handler) = r
    #(method, segments_to_pattern(segments))
  })
}

fn segments_to_pattern(segments: List(ipath.Segment)) -> String {
  case segments {
    [] -> "/"
    _ ->
      "/"
      <> list.map(segments, fn(seg) {
        case seg {
          ipath.Literal(s) -> s
          ipath.Capture(name, ipath.IntT) -> "<" <> name <> ":int>"
          ipath.Capture(name, ipath.StringT) -> "<" <> name <> ":string>"
          ipath.Wildcard(name) -> "*" <> name
        }
      })
      |> string.join("/")
  }
}

/// Build a URL path from a route pattern and a list of `(name, value)` pairs.
///
/// Returns `Error(Nil)` if any named parameter is missing from the list.
/// Extra keys in the list are silently ignored.
///
/// ```gleam
/// radiant.path_for("/users/<id:int>/posts/<pid:int>", [
///   #("id", "42"), #("pid", "7"),
/// ])
/// // → Ok("/users/42/posts/7")
///
/// radiant.path_for("/users/<id:int>", [])
/// // → Error(Nil)
/// ```
pub fn path_for(
  pattern: String,
  params: List(#(String, String)),
) -> Result(String, Nil) {
  let segments = ipath.parse(pattern)
  let lookup = dict.from_list(params)
  use parts <- result.try(
    list.try_map(segments, fn(seg) {
      case seg {
        ipath.Literal(s) -> Ok(s)
        ipath.Capture(name, _) -> dict.get(lookup, name)
        ipath.Wildcard(name) -> dict.get(lookup, name)
      }
    }),
  )
  case parts {
    [] -> Ok("/")
    _ -> Ok("/" <> string.join(parts, "/"))
  }
}

/// Build a URL path using typed `Param` objects — more refactor-safe than `path_for`.
///
/// Because you pass the same `Param` constant used for route registration,
/// renaming a capture in the pattern and updating the `Param` name is enough:
/// `validate_param` will catch any remaining mismatch at startup.
///
/// ```gleam
/// pub const user_id = radiant.int("id")
///
/// // Route registration
/// router |> radiant.get1("/users/<id:int>", user_id, handler)
///
/// // URL building — user_id.name is always in sync with the route
/// radiant.path_for1("/users/<id:int>", user_id, 42)
/// // → Ok("/users/42")
/// ```
pub fn path_for1(pattern: String, p1: Param(a), v1: a) -> Result(String, Nil) {
  path_for(pattern, [#(p1.name, p1.to_string(v1))])
}

/// Build a URL path with two typed parameters.
pub fn path_for2(
  pattern: String,
  p1: Param(a),
  v1: a,
  p2: Param(b),
  v2: b,
) -> Result(String, Nil) {
  path_for(pattern, [#(p1.name, p1.to_string(v1)), #(p2.name, p2.to_string(v2))])
}

/// Build a URL path with three typed parameters.
pub fn path_for3(
  pattern: String,
  p1: Param(a),
  v1: a,
  p2: Param(b),
  v2: b,
  p3: Param(c),
  v3: c,
) -> Result(String, Nil) {
  path_for(pattern, [
    #(p1.name, p1.to_string(v1)),
    #(p2.name, p2.to_string(v2)),
    #(p3.name, p3.to_string(v3)),
  ])
}

/// Build a URL path with four typed parameters.
pub fn path_for4(
  pattern: String,
  p1: Param(a),
  v1: a,
  p2: Param(b),
  v2: b,
  p3: Param(c),
  v3: c,
  p4: Param(d),
  v4: d,
) -> Result(String, Nil) {
  path_for(pattern, [
    #(p1.name, p1.to_string(v1)),
    #(p2.name, p2.to_string(v2)),
    #(p3.name, p3.to_string(v3)),
    #(p4.name, p4.to_string(v4)),
  ])
}

/// Build a URL path with five typed parameters.
pub fn path_for5(
  pattern: String,
  p1: Param(a),
  v1: a,
  p2: Param(b),
  v2: b,
  p3: Param(c),
  v3: c,
  p4: Param(d),
  v4: d,
  p5: Param(e),
  v5: e,
) -> Result(String, Nil) {
  path_for(pattern, [
    #(p1.name, p1.to_string(v1)),
    #(p2.name, p2.to_string(v2)),
    #(p3.name, p3.to_string(v3)),
    #(p4.name, p4.to_string(v4)),
    #(p5.name, p5.to_string(v5)),
  ])
}

/// Build a URL path with six typed parameters.
pub fn path_for6(
  pattern: String,
  p1: Param(a),
  v1: a,
  p2: Param(b),
  v2: b,
  p3: Param(c),
  v3: c,
  p4: Param(d),
  v4: d,
  p5: Param(e),
  v5: e,
  p6: Param(f),
  v6: f,
) -> Result(String, Nil) {
  path_for(pattern, [
    #(p1.name, p1.to_string(v1)),
    #(p2.name, p2.to_string(v2)),
    #(p3.name, p3.to_string(v3)),
    #(p4.name, p4.to_string(v4)),
    #(p5.name, p5.to_string(v5)),
    #(p6.name, p6.to_string(v6)),
  ])
}

fn add_route(
  router: Router,
  method: Method,
  pattern: String,
  handler: fn(Req) -> Response(BitArray),
) -> Router {
  add_route_raw(router, method, ipath.parse(pattern), handler)
}

fn add_route_raw(
  router: Router,
  method: Method,
  segments: List(ipath.Segment),
  handler: fn(Req) -> Response(BitArray),
) -> Router {
  let _ = case tree.check_capture_ambiguity(router.tree, segments) {
    Ok(existing) -> {
      let pattern = segments_to_pattern(segments)
      panic as {
        "Radiant: Ambiguous capture in '"
        <> pattern
        <> "'. A capture named '"
        <> existing
        <> "' of the same type already exists at the same path depth. "
        <> "Routing between them is order-dependent. Use distinct types or restructure your routes."
      }
    }
    Error(_) -> Nil
  }
  case tree.get_handler(router.tree, segments, method) {
    Ok(_) -> router
    Error(_) ->
      Router(
        ..router,
        tree: tree.insert(router.tree, method, segments, handler),
      )
  }
}

// Verify that a Param's name refers to an actual capture in the pattern.
// Panics at route-registration time (startup) if mismatched, not at request time.
fn validate_param(
  p: Param(a),
  segments: List(ipath.Segment),
  pattern: String,
) -> Nil {
  case
    list.any(segments, fn(seg) {
      case seg {
        ipath.Capture(name, _) -> name == p.name
        ipath.Wildcard(name) -> name == p.name
        _ -> False
      }
    })
  {
    True -> Nil
    False ->
      panic as {
        "Radiant: param '"
        <> p.name
        <> "' not found in pattern '"
        <> pattern
        <> "'. The Param name must match a capture in the route pattern."
      }
  }
}

// Upgrade the type constraint of a named capture to match a Param's ptype.
fn apply_param_type(
  segments: List(ipath.Segment),
  p: Param(a),
) -> List(ipath.Segment) {
  list.map(segments, fn(seg) {
    case seg {
      ipath.Capture(name, _) if name == p.name -> ipath.Capture(name, p.ptype)
      _ -> seg
    }
  })
}

fn typed1(
  router: Router,
  method: Method,
  pattern: String,
  p1: Param(a),
  handler: fn(Req, a) -> Response(BitArray),
) -> Router {
  let raw = ipath.parse(pattern)
  validate_param(p1, raw, pattern)
  let segments = apply_param_type(raw, p1)
  let wrapped = fn(req: Req) -> Response(BitArray) {
    let assert Ok(v1) = dict.get(req.params, p1.name) |> result.try(p1.parse)
    handler(req, v1)
  }
  add_route_raw(router, method, segments, wrapped)
}

fn typed2(
  router: Router,
  method: Method,
  pattern: String,
  p1: Param(a),
  p2: Param(b),
  handler: fn(Req, a, b) -> Response(BitArray),
) -> Router {
  let raw = ipath.parse(pattern)
  validate_param(p1, raw, pattern)
  validate_param(p2, raw, pattern)
  let segments = raw |> apply_param_type(p1) |> apply_param_type(p2)
  let wrapped = fn(req: Req) -> Response(BitArray) {
    let assert Ok(v1) = dict.get(req.params, p1.name) |> result.try(p1.parse)
    let assert Ok(v2) = dict.get(req.params, p2.name) |> result.try(p2.parse)
    handler(req, v1, v2)
  }
  add_route_raw(router, method, segments, wrapped)
}

fn typed3(
  router: Router,
  method: Method,
  pattern: String,
  p1: Param(a),
  p2: Param(b),
  p3: Param(c),
  handler: fn(Req, a, b, c) -> Response(BitArray),
) -> Router {
  let raw = ipath.parse(pattern)
  validate_param(p1, raw, pattern)
  validate_param(p2, raw, pattern)
  validate_param(p3, raw, pattern)
  let segments =
    raw |> apply_param_type(p1) |> apply_param_type(p2) |> apply_param_type(p3)
  let wrapped = fn(req: Req) -> Response(BitArray) {
    let assert Ok(v1) = dict.get(req.params, p1.name) |> result.try(p1.parse)
    let assert Ok(v2) = dict.get(req.params, p2.name) |> result.try(p2.parse)
    let assert Ok(v3) = dict.get(req.params, p3.name) |> result.try(p3.parse)
    handler(req, v1, v2, v3)
  }
  add_route_raw(router, method, segments, wrapped)
}

fn typed4(
  router: Router,
  method: Method,
  pattern: String,
  p1: Param(a),
  p2: Param(b),
  p3: Param(c),
  p4: Param(d),
  handler: fn(Req, a, b, c, d) -> Response(BitArray),
) -> Router {
  let raw = ipath.parse(pattern)
  validate_param(p1, raw, pattern)
  validate_param(p2, raw, pattern)
  validate_param(p3, raw, pattern)
  validate_param(p4, raw, pattern)
  let segments =
    raw
    |> apply_param_type(p1)
    |> apply_param_type(p2)
    |> apply_param_type(p3)
    |> apply_param_type(p4)
  let wrapped = fn(req: Req) -> Response(BitArray) {
    let assert Ok(v1) = dict.get(req.params, p1.name) |> result.try(p1.parse)
    let assert Ok(v2) = dict.get(req.params, p2.name) |> result.try(p2.parse)
    let assert Ok(v3) = dict.get(req.params, p3.name) |> result.try(p3.parse)
    let assert Ok(v4) = dict.get(req.params, p4.name) |> result.try(p4.parse)
    handler(req, v1, v2, v3, v4)
  }
  add_route_raw(router, method, segments, wrapped)
}

fn typed5(
  router: Router,
  method: Method,
  pattern: String,
  p1: Param(a),
  p2: Param(b),
  p3: Param(c),
  p4: Param(d),
  p5: Param(e),
  handler: fn(Req, a, b, c, d, e) -> Response(BitArray),
) -> Router {
  let raw = ipath.parse(pattern)
  validate_param(p1, raw, pattern)
  validate_param(p2, raw, pattern)
  validate_param(p3, raw, pattern)
  validate_param(p4, raw, pattern)
  validate_param(p5, raw, pattern)
  let segments =
    raw
    |> apply_param_type(p1)
    |> apply_param_type(p2)
    |> apply_param_type(p3)
    |> apply_param_type(p4)
    |> apply_param_type(p5)
  let wrapped = fn(req: Req) -> Response(BitArray) {
    let assert Ok(v1) = dict.get(req.params, p1.name) |> result.try(p1.parse)
    let assert Ok(v2) = dict.get(req.params, p2.name) |> result.try(p2.parse)
    let assert Ok(v3) = dict.get(req.params, p3.name) |> result.try(p3.parse)
    let assert Ok(v4) = dict.get(req.params, p4.name) |> result.try(p4.parse)
    let assert Ok(v5) = dict.get(req.params, p5.name) |> result.try(p5.parse)
    handler(req, v1, v2, v3, v4, v5)
  }
  add_route_raw(router, method, segments, wrapped)
}

fn typed6(
  router: Router,
  method: Method,
  pattern: String,
  p1: Param(a),
  p2: Param(b),
  p3: Param(c),
  p4: Param(d),
  p5: Param(e),
  p6: Param(f),
  handler: fn(Req, a, b, c, d, e, f) -> Response(BitArray),
) -> Router {
  let raw = ipath.parse(pattern)
  validate_param(p1, raw, pattern)
  validate_param(p2, raw, pattern)
  validate_param(p3, raw, pattern)
  validate_param(p4, raw, pattern)
  validate_param(p5, raw, pattern)
  validate_param(p6, raw, pattern)
  let segments =
    raw
    |> apply_param_type(p1)
    |> apply_param_type(p2)
    |> apply_param_type(p3)
    |> apply_param_type(p4)
    |> apply_param_type(p5)
    |> apply_param_type(p6)
  let wrapped = fn(req: Req) -> Response(BitArray) {
    let assert Ok(v1) = dict.get(req.params, p1.name) |> result.try(p1.parse)
    let assert Ok(v2) = dict.get(req.params, p2.name) |> result.try(p2.parse)
    let assert Ok(v3) = dict.get(req.params, p3.name) |> result.try(p3.parse)
    let assert Ok(v4) = dict.get(req.params, p4.name) |> result.try(p4.parse)
    let assert Ok(v5) = dict.get(req.params, p5.name) |> result.try(p5.parse)
    let assert Ok(v6) = dict.get(req.params, p6.name) |> result.try(p6.parse)
    handler(req, v1, v2, v3, v4, v5, v6)
  }
  add_route_raw(router, method, segments, wrapped)
}

// ---------------------------------------------------------------------------
// Req — accessors
// ---------------------------------------------------------------------------

/// The request HTTP method.
pub fn method(req: Req) -> Method {
  req.request.method
}

/// The request path (e.g. "/users/42").
pub fn req_path(req: Req) -> String {
  req.request.path
}

/// Get a request header by key (case-insensitive).
pub fn header(req: Req, key: String) -> Result(String, Nil) {
  request.get_header(req.request, key)
}

/// All request headers.
pub fn headers(req: Req) -> List(#(String, String)) {
  req.request.headers
}

/// The raw request body as BitArray.
pub fn body(req: Req) -> BitArray {
  req.request.body
}

/// The request body decoded as UTF-8 text.
pub fn text_body(req: Req) -> Result(String, Nil) {
  bit_array.to_string(req.request.body)
}

/// Extract a path parameter as String.
///
/// ```gleam
/// // pattern: "/users/:name"
/// radiant.str_param(req, "name")  // Ok("alice")
/// ```
pub fn str_param(req: Req, name: String) -> Result(String, Nil) {
  dict.get(req.params, name)
}

/// Extract a path parameter and parse it as Int.
///
/// ```gleam
/// // pattern: "/users/:id"
/// radiant.int_param(req, "id")  // Ok(42)
/// ```
pub fn int_param(req: Req, name: String) -> Result(Int, Nil) {
  dict.get(req.params, name)
  |> result.try(int.parse)
}

/// Get a single query parameter by key.
pub fn query(req: Req, key: String) -> Result(String, Nil) {
  queries(req)
  |> list.key_find(key)
}

/// All query parameters as key-value pairs.
pub fn queries(req: Req) -> List(#(String, String)) {
  case req.request.query {
    Some(q) ->
      case uri.parse_query(q) {
        Ok(pairs) -> pairs
        Error(Nil) -> []
      }
    None -> []
  }
}

/// Get a query parameter parsed as Int.
pub fn query_int(req: Req, key: String) -> Result(Int, Nil) {
  query(req, key) |> result.try(int.parse)
}

/// Get a query parameter parsed as Float.
pub fn query_float(req: Req, key: String) -> Result(Float, Nil) {
  query(req, key) |> result.try(float.parse)
}

/// Get a query parameter parsed as Bool.
/// Accepts `"true"`/`"1"` → `True`, `"false"`/`"0"` → `False`. Anything else returns `Error(Nil)`.
pub fn query_bool(req: Req, key: String) -> Result(Bool, Nil) {
  case query(req, key) {
    Ok("true") | Ok("1") -> Ok(True)
    Ok("false") | Ok("0") -> Ok(False)
    _ -> Error(Nil)
  }
}

/// Access the underlying `Request(BitArray)` for anything radiant doesn't wrap.
pub fn original(req: Req) -> Request(BitArray) {
  req.request
}

/// Store a typed value in the request context.
/// Use a `Key(a)` constant to guarantee type-safe retrieval.
///
/// ```gleam
/// pub const user_key: radiant.Key(User) = radiant.key("user")
///
/// radiant.set_context(req, user_key, User(name: "Alice"))
/// ```
pub fn set_context(req: Req, k: Key(a), value: a) -> Req {
  let Key(name) = k
  Req(..req, context: dict.insert(req.context, name, unsafe_coerce(value)))
}

/// Retrieve a typed value from the request context.
/// Returns `Ok(a)` if the key was set, `Error(Nil)` otherwise.
///
/// ```gleam
/// let assert Ok(user) = radiant.get_context(req, user_key)
/// ```
pub fn get_context(req: Req, k: Key(a)) -> Result(a, Nil) {
  let Key(name) = k
  case dict.get(req.context, name) {
    Ok(dyn) -> Ok(unsafe_coerce(dyn))
    Error(_) -> Error(Nil)
  }
}

// Identity function used for type-erasing values into the context dict
// and recovering them out. Safe as long as callers use Key(a) correctly.
@external(erlang, "gleam_stdlib", "identity")
@external(javascript, "../gleam_stdlib.mjs", "identity")
fn unsafe_coerce(a: a) -> b

// ---------------------------------------------------------------------------
// Response helpers
// ---------------------------------------------------------------------------

/// Build a response with the given status and UTF-8 text body.
pub fn response(status: Int, body_text: String) -> Response(BitArray) {
  Response(status:, headers: [], body: <<body_text:utf8>>)
}

/// 200 OK with text body.
pub fn ok(body_text: String) -> Response(BitArray) {
  response(200, body_text)
}

/// 201 Created with text body.
pub fn created(body_text: String) -> Response(BitArray) {
  response(201, body_text)
}

/// 204 No Content (empty body).
pub fn no_content() -> Response(BitArray) {
  response(204, "")
}

/// 404 Not Found (empty body).
pub fn not_found() -> Response(BitArray) {
  response(404, "")
}

/// 400 Bad Request (empty body).
pub fn bad_request() -> Response(BitArray) {
  response(400, "")
}

/// 401 Unauthorized (empty body).
/// Set `www-authenticate` with `with_header` if needed.
pub fn unauthorized() -> Response(BitArray) {
  response(401, "")
}

/// 403 Forbidden (empty body).
pub fn forbidden() -> Response(BitArray) {
  response(403, "")
}

/// 405 Method Not Allowed with an `allow` header.
pub fn method_not_allowed(allowed: String) -> Response(BitArray) {
  response(405, "")
  |> with_header("allow", allowed)
}

/// 422 Unprocessable Entity (empty body).
/// Standard response for semantic validation failures (e.g. invalid field values).
pub fn unprocessable_entity() -> Response(BitArray) {
  response(422, "")
}

/// 500 Internal Server Error (empty body).
pub fn internal_server_error() -> Response(BitArray) {
  response(500, "")
}

/// 400 Bad Request with a text body.
pub fn bad_request_with(body_text: String) -> Response(BitArray) {
  response(400, body_text)
}

/// 401 Unauthorized with a text body.
pub fn unauthorized_with(body_text: String) -> Response(BitArray) {
  response(401, body_text)
}

/// 403 Forbidden with a text body.
pub fn forbidden_with(body_text: String) -> Response(BitArray) {
  response(403, body_text)
}

/// 404 Not Found with a text body.
pub fn not_found_with(body_text: String) -> Response(BitArray) {
  response(404, body_text)
}

/// 422 Unprocessable Entity with a text body.
pub fn unprocessable_entity_with(body_text: String) -> Response(BitArray) {
  response(422, body_text)
}

/// 500 Internal Server Error with a text body.
pub fn internal_server_error_with(body_text: String) -> Response(BitArray) {
  response(500, body_text)
}

/// JSON error response: `{"error": "message"}` with `application/json` content-type.
///
/// ```gleam
/// radiant.json_error(404, "user not found")
/// // → 404 {"error":"user not found"}
/// ```
pub fn json_error(status: Int, message: String) -> Response(BitArray) {
  let body =
    gjson.to_string(gjson.object([#("error", gjson.string(message))]))
  response(status, body)
  |> with_header("content-type", "application/json; charset=utf-8")
}

/// 303 See Other redirect.
pub fn redirect(uri: String) -> Response(BitArray) {
  Response(status: 303, headers: [#("location", uri)], body: <<>>)
}

/// 200 OK with `content-type: application/json`.
pub fn json(body_text: String) -> Response(BitArray) {
  response(200, body_text)
  |> with_header("content-type", "application/json; charset=utf-8")
}

/// 200 OK with `content-type: text/html`.
pub fn html(body_text: String) -> Response(BitArray) {
  response(200, body_text)
  |> with_header("content-type", "text/html; charset=utf-8")
}

/// Set a header on a response (key is lowercased automatically).
pub fn with_header(
  resp: Response(BitArray),
  key: String,
  value: String,
) -> Response(BitArray) {
  response.set_header(resp, key, value)
}

// ---------------------------------------------------------------------------
// Built-in middleware
// ---------------------------------------------------------------------------

/// Configuration for the CORS middleware.
///
/// - `origins`: list of allowed origins, or `["*"]` for any origin
/// - `methods`: list of allowed HTTP methods
/// - `headers`: list of allowed request headers
/// - `max_age`: how long (in seconds) browsers should cache preflight results
pub type CorsConfig {
  CorsConfig(
    origins: List(String),
    methods: List(Method),
    headers: List(String),
    max_age: Int,
  )
}

/// Sensible default CORS config.
///
/// - Origins: `["*"]` (any)
/// - Methods: GET, POST, PUT, PATCH, DELETE
/// - Headers: `content-type`, `authorization`
/// - Max age: 86400 seconds (24 hours)
pub fn default_cors() -> CorsConfig {
  CorsConfig(
    origins: ["*"],
    methods: [Get, Post, Put, Patch, Delete],
    headers: ["content-type", "authorization"],
    max_age: 86_400,
  )
}

/// CORS middleware. Handles preflight `OPTIONS` requests automatically and
/// sets `access-control-allow-*` headers on all responses.
///
/// ```gleam
/// radiant.new()
/// |> radiant.middleware(radiant.cors(radiant.default_cors()))
/// ```
pub fn cors(config: CorsConfig) -> Middleware {
  fn(next) {
    fn(req) {
      let origin = header(req, "origin") |> result.unwrap("")
      let allowed =
        origin != ""
        && {
          list.contains(config.origins, "*")
          || list.contains(config.origins, origin)
        }
      case method(req) {
        http.Options ->
          case allowed {
            True ->
              no_content()
              |> with_header("access-control-allow-origin", origin)
              |> with_header(
                "access-control-allow-methods",
                config.methods
                  |> list.map(http.method_to_string)
                  |> string.join(", "),
              )
              |> with_header(
                "access-control-allow-headers",
                string.join(config.headers, ", "),
              )
              |> with_header(
                "access-control-max-age",
                int.to_string(config.max_age),
              )
            False -> no_content()
          }
        _ -> {
          let resp = next(req)
          case allowed {
            True -> with_header(resp, "access-control-allow-origin", origin)
            False -> resp
          }
        }
      }
    }
  }
}

/// Logging middleware. Takes a logging function and calls it before and after
/// each request with method, path, and status code.
///
/// Works with any logger — woof, io.println, or your own:
///
/// ```gleam
/// // With io.println:
/// radiant.log(io.println)
///
/// // With woof:
/// radiant.log(fn(msg) { woof.log(logger, woof.Info, msg, []) })
/// ```
pub fn log(logger: fn(String) -> a) -> Middleware {
  fn(next) {
    fn(req) {
      let m = http.method_to_string(method(req))
      let p = req_path(req)
      logger(m <> " " <> p)
      let resp: Response(BitArray) = next(req)
      logger(m <> " " <> p <> " → " <> int.to_string(resp.status))
      resp
    }
  }
}

/// Rescue middleware. Catches Erlang exceptions (panics) in handlers and
/// returns a 500 response instead of crashing the process.
///
/// The callback receives the exception for logging or error reporting.
///
/// ```gleam
/// radiant.new()
/// |> radiant.middleware(radiant.rescue(fn(err) {
///   io.debug(err)
///   radiant.response(500, "Internal server error")
/// }))
/// ```
pub fn rescue(
  on_error: fn(exception.Exception) -> Response(BitArray),
) -> Middleware {
  fn(next) {
    fn(req) {
      case exception.rescue(fn() { next(req) }) {
        Ok(resp) -> resp
        Error(err) -> on_error(err)
      }
    }
  }
}

/// A middleware that parses the request body as JSON and stores it in the
/// request context under the given typed key.
///
/// If the body is not valid JSON or does not match the decoder,
/// returns `400 Bad Request` immediately.
///
/// ```gleam
/// pub const user_key: radiant.Key(User) = radiant.key("user")
///
/// let user_decoder = {
///   use name <- decode.field("name", decode.string)
///   decode.success(User(name))
/// }
///
/// radiant.new()
/// |> radiant.middleware(radiant.json_body(user_key, user_decoder))
/// |> radiant.post("/users", fn(req) {
///   let assert Ok(user) = radiant.get_context(req, user_key)
///   radiant.ok("Hello " <> user.name)
/// })
/// ```
pub fn json_body(key: Key(a), decoder: decode.Decoder(a)) -> Middleware {
  fn(next) {
    fn(req) {
      // Skip parsing when the body is empty (e.g. GET, HEAD, DELETE requests).
      // The handler will receive Error(Nil) from get_context if it needs the value.
      case body(req) {
        <<>> -> next(req)
        _ ->
          case text_body(req) {
            Ok(b) ->
              case gjson.parse(b, decoder) {
                Ok(val) -> next(set_context(req, key, val))
                Error(_) -> bad_request()
              }
            Error(_) -> bad_request()
          }
      }
    }
  }
}

/// A middleware that serves static files from a directory.
///
/// It strips the `prefix` from the request path and looks for the remaining
/// path inside the `directory`.
///
/// If a file is found, it's served with a guessed Mime-Type.
/// Otherwise, it falls back to the next handler (usualy a 404 fallback).
pub fn serve_static(
  prefix prefix: String,
  from directory: String,
  via fs: FileSystem,
) -> Middleware {
  let prefix = case string.starts_with(prefix, "/") {
    True -> prefix
    False -> "/" <> prefix
  }

  fn(next) {
    fn(req) {
      let path = req_path(req)
      case string.starts_with(path, prefix) {
        True -> {
          let rel_path =
            string.drop_start(path, string.length(prefix))
            |> string.split("/")
            |> list.filter(fn(s) { s != "" && s != ".." })
            |> string.join("/")

          let full_path = case directory {
            "." -> rel_path
            _ -> directory <> "/" <> rel_path
          }

          case fs.is_file(full_path) {
            True -> {
              case fs.read_bits(full_path) {
                Ok(bits) -> {
                  let mime = mime_from_path(full_path)
                  response.new(200)
                  |> response.set_body(bits)
                  |> response.set_header("content-type", mime)
                }
                Error(_) -> next(req)
              }
            }
            False -> next(req)
          }
        }
        False -> next(req)
      }
    }
  }
}

fn mime_from_path(path: String) -> String {
  let ext =
    path
    |> string.split(".")
    |> list.last()
    |> result.unwrap("")
    |> string.lowercase()

  case ext {
    "html" | "htm" -> "text/html"
    "css" -> "text/css"
    "js" -> "application/javascript"
    "json" -> "application/json"
    "png" -> "image/png"
    "jpg" | "jpeg" -> "image/jpeg"
    "gif" -> "image/gif"
    "svg" -> "image/svg+xml"
    "txt" -> "text/plain"
    _ -> "application/octet-stream"
  }
}

// ---------------------------------------------------------------------------
// Testing helpers
// ---------------------------------------------------------------------------

/// Create a test request with the given method and path.
/// Supports query strings: `test_request(Get, "/search?q=gleam")`.
///
/// Note: import `gleam/http.{Get, Post, ...}` for method constructors.
pub fn test_request(method: Method, raw_path: String) -> Request(BitArray) {
  case string.split_once(raw_path, on: "?") {
    Ok(#(p, q)) ->
      request.new()
      |> request.set_method(method)
      |> request.set_path(p)
      |> fn(r) { Request(..r, query: Some(q)) }
      |> request.set_body(<<>>)
    Error(Nil) ->
      request.new()
      |> request.set_method(method)
      |> request.set_path(raw_path)
      |> request.set_body(<<>>)
  }
}

/// Shortcut: create a GET test request.
pub fn test_get(raw_path: String) -> Request(BitArray) {
  test_request(Get, raw_path)
}

/// Shortcut: create a POST test request with a UTF-8 body.
pub fn test_post(raw_path: String, body_text: String) -> Request(BitArray) {
  test_request(Post, raw_path)
  |> request.set_body(<<body_text:utf8>>)
}

/// Shortcut: create a PUT test request with a UTF-8 body.
pub fn test_put(raw_path: String, body_text: String) -> Request(BitArray) {
  test_request(Put, raw_path)
  |> request.set_body(<<body_text:utf8>>)
}

/// Shortcut: create a PATCH test request with a UTF-8 body.
pub fn test_patch(raw_path: String, body_text: String) -> Request(BitArray) {
  test_request(Patch, raw_path)
  |> request.set_body(<<body_text:utf8>>)
}

/// Shortcut: create a DELETE test request.
pub fn test_delete(raw_path: String) -> Request(BitArray) {
  test_request(Delete, raw_path)
}

/// Shortcut: create a HEAD test request.
pub fn test_head(raw_path: String) -> Request(BitArray) {
  test_request(http.Head, raw_path)
}

/// Shortcut: create an OPTIONS test request.
pub fn test_options(raw_path: String) -> Request(BitArray) {
  test_request(http.Options, raw_path)
}

// ---------------------------------------------------------------------------
// Assertions (Testing)
// ---------------------------------------------------------------------------

/// Assert that a response has the expected status code.
/// Panics if the status doesn't match.
pub fn should_have_status(
  resp: Response(BitArray),
  expected: Int,
) -> Response(BitArray) {
  case resp.status == expected {
    True -> resp
    False -> {
      let msg =
        "Radiant Test: Expected status "
        <> int.to_string(expected)
        <> ", got "
        <> int.to_string(resp.status)
      panic as msg
    }
  }
}

/// Assert that a response has the expected body.
/// Panics if the body doesn't match.
pub fn should_have_body(
  resp: Response(BitArray),
  expected: String,
) -> Response(BitArray) {
  let expected_bits = <<expected:utf8>>
  case resp.body == expected_bits {
    True -> resp
    False -> {
      let actual = bit_array.to_string(resp.body) |> result.unwrap("<non-utf8>")
      panic as {
        "Radiant Test: Expected body \""
        <> expected
        <> "\", got \""
        <> actual
        <> "\""
      }
    }
  }
}

/// Assert that a response has the expected header value.
/// Panics if the header is missing or doesn't match.
pub fn should_have_header(
  resp: Response(BitArray),
  name: String,
  expected: String,
) -> Response(BitArray) {
  case response.get_header(resp, name) {
    Ok(val) if val == expected -> resp
    Ok(val) -> {
      panic as {
        "Radiant Test: Expected header '"
        <> name
        <> "' to be '"
        <> expected
        <> "', got '"
        <> val
        <> "'"
      }
    }
    Error(Nil) -> {
      panic as { "Radiant Test: Missing expected header '" <> name <> "'" }
    }
  }
}

/// Parse the response body as JSON and verify it matches the decoder.
/// Returns the decoded value for further assertions.
/// Panics if parsing fails.
pub fn should_have_json_body(
  resp: Response(BitArray),
  decoder: decode.Decoder(a),
) -> a {
  let body = case bit_array.to_string(resp.body) {
    Ok(s) -> s
    Error(_) -> panic as "Radiant Test: Response body is not valid UTF-8"
  }

  case gjson.parse(body, decoder) {
    Ok(val) -> val
    Error(_) -> panic as "Radiant Test: Failed to decode JSON response body"
  }
}
