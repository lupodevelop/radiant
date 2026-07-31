//// Router types, route registration, and dispatch.

import gleam/dict
import gleam/http.{
  type Method, Connect, Delete, Get, Head, Options, Other, Patch, Post, Put,
  Trace,
}
import gleam/http/request.{type Request}
import gleam/http/response.{type Response, Response}
import gleam/int
import gleam/list
import gleam/result
import gleam/string
import gleam/uri
import radiant/internal/path as ipath
import radiant/internal/tree
import radiant/request as radiant_request
import radiant/response as radiant_response

/// An opaque router that maps HTTP method + path pattern to handlers.
pub opaque type Router {
  Router(
    tree: tree.Node(fn(radiant_request.Req) -> Response(BitArray)),
    fallback: fn(radiant_request.Req) -> Response(BitArray),
    middlewares: List(Middleware),
  )
}

/// A middleware transforms a handler into a new handler.
pub type Middleware =
  fn(fn(radiant_request.Req) -> Response(BitArray)) ->
    fn(radiant_request.Req) -> Response(BitArray)

/// A typed path parameter for use with `get1`, `get2`, and friends.
pub opaque type Param(a) {
  Param(
    name: String,
    parse: fn(String) -> Result(a, Nil),
    ptype: ipath.ParamType,
    to_string: fn(a) -> String,
  )
}

/// The HTTP QUERY method from RFC 10008.
pub const query_method: Method = Other("QUERY")

pub fn int(name: String) -> Param(Int) {
  Param(
    name: name,
    parse: int.parse,
    ptype: ipath.IntT,
    to_string: int.to_string,
  )
}

pub fn str(name: String) -> Param(String) {
  Param(
    name: name,
    parse: fn(s) { Ok(s) },
    ptype: ipath.StringT,
    to_string: fn(s) { s },
  )
}

pub fn new() -> Router {
  Router(
    tree: tree.new(),
    fallback: fn(_req) { radiant_response.not_found() },
    middlewares: [],
  )
}

pub fn fallback(
  router: Router,
  handler: fn(radiant_request.Req) -> Response(BitArray),
) -> Router {
  Router(..router, fallback: handler)
}

pub fn middleware(router: Router, mw: Middleware) -> Router {
  Router(..router, middlewares: [mw, ..router.middlewares])
}

pub fn wrap(
  mw: Middleware,
  handler: fn(radiant_request.Req) -> Response(BitArray),
) -> fn(radiant_request.Req) -> Response(BitArray) {
  mw(handler)
}

pub fn get(
  router: Router,
  pattern: String,
  handler: fn(radiant_request.Req) -> Response(BitArray),
) -> Router {
  add_route(router, Get, pattern, handler)
}

pub fn post(
  router: Router,
  pattern: String,
  handler: fn(radiant_request.Req) -> Response(BitArray),
) -> Router {
  add_route(router, Post, pattern, handler)
}

pub fn put(
  router: Router,
  pattern: String,
  handler: fn(radiant_request.Req) -> Response(BitArray),
) -> Router {
  add_route(router, Put, pattern, handler)
}

pub fn patch(
  router: Router,
  pattern: String,
  handler: fn(radiant_request.Req) -> Response(BitArray),
) -> Router {
  add_route(router, Patch, pattern, handler)
}

pub fn delete(
  router: Router,
  pattern: String,
  handler: fn(radiant_request.Req) -> Response(BitArray),
) -> Router {
  add_route(router, Delete, pattern, handler)
}

pub fn options(
  router: Router,
  pattern: String,
  handler: fn(radiant_request.Req) -> Response(BitArray),
) -> Router {
  add_route(router, Options, pattern, handler)
}

/// Register a route for any HTTP method.
pub fn route(
  router: Router,
  method: Method,
  pattern: String,
  handler: fn(radiant_request.Req) -> Response(BitArray),
) -> Router {
  add_route(router, method, pattern, handler)
}

pub fn query_route(
  router: Router,
  pattern: String,
  handler: fn(radiant_request.Req) -> Response(BitArray),
) -> Router {
  add_route(router, query_method, pattern, handler)
}

pub fn get1(
  router: Router,
  pattern: String,
  p1: Param(a),
  handler: fn(radiant_request.Req, a) -> Response(BitArray),
) -> Router {
  typed1(router, Get, pattern, p1, handler)
}

pub fn post1(
  router: Router,
  pattern: String,
  p1: Param(a),
  handler: fn(radiant_request.Req, a) -> Response(BitArray),
) -> Router {
  typed1(router, Post, pattern, p1, handler)
}

pub fn put1(
  router: Router,
  pattern: String,
  p1: Param(a),
  handler: fn(radiant_request.Req, a) -> Response(BitArray),
) -> Router {
  typed1(router, Put, pattern, p1, handler)
}

pub fn patch1(
  router: Router,
  pattern: String,
  p1: Param(a),
  handler: fn(radiant_request.Req, a) -> Response(BitArray),
) -> Router {
  typed1(router, Patch, pattern, p1, handler)
}

pub fn delete1(
  router: Router,
  pattern: String,
  p1: Param(a),
  handler: fn(radiant_request.Req, a) -> Response(BitArray),
) -> Router {
  typed1(router, Delete, pattern, p1, handler)
}

pub fn get2(
  router: Router,
  pattern: String,
  p1: Param(a),
  p2: Param(b),
  handler: fn(radiant_request.Req, a, b) -> Response(BitArray),
) -> Router {
  typed2(router, Get, pattern, p1, p2, handler)
}

pub fn post2(
  router: Router,
  pattern: String,
  p1: Param(a),
  p2: Param(b),
  handler: fn(radiant_request.Req, a, b) -> Response(BitArray),
) -> Router {
  typed2(router, Post, pattern, p1, p2, handler)
}

pub fn put2(
  router: Router,
  pattern: String,
  p1: Param(a),
  p2: Param(b),
  handler: fn(radiant_request.Req, a, b) -> Response(BitArray),
) -> Router {
  typed2(router, Put, pattern, p1, p2, handler)
}

pub fn patch2(
  router: Router,
  pattern: String,
  p1: Param(a),
  p2: Param(b),
  handler: fn(radiant_request.Req, a, b) -> Response(BitArray),
) -> Router {
  typed2(router, Patch, pattern, p1, p2, handler)
}

pub fn delete2(
  router: Router,
  pattern: String,
  p1: Param(a),
  p2: Param(b),
  handler: fn(radiant_request.Req, a, b) -> Response(BitArray),
) -> Router {
  typed2(router, Delete, pattern, p1, p2, handler)
}

pub fn get3(
  router: Router,
  pattern: String,
  p1: Param(a),
  p2: Param(b),
  p3: Param(c),
  handler: fn(radiant_request.Req, a, b, c) -> Response(BitArray),
) -> Router {
  typed3(router, Get, pattern, p1, p2, p3, handler)
}

pub fn post3(
  router: Router,
  pattern: String,
  p1: Param(a),
  p2: Param(b),
  p3: Param(c),
  handler: fn(radiant_request.Req, a, b, c) -> Response(BitArray),
) -> Router {
  typed3(router, Post, pattern, p1, p2, p3, handler)
}

pub fn put3(
  router: Router,
  pattern: String,
  p1: Param(a),
  p2: Param(b),
  p3: Param(c),
  handler: fn(radiant_request.Req, a, b, c) -> Response(BitArray),
) -> Router {
  typed3(router, Put, pattern, p1, p2, p3, handler)
}

pub fn patch3(
  router: Router,
  pattern: String,
  p1: Param(a),
  p2: Param(b),
  p3: Param(c),
  handler: fn(radiant_request.Req, a, b, c) -> Response(BitArray),
) -> Router {
  typed3(router, Patch, pattern, p1, p2, p3, handler)
}

pub fn delete3(
  router: Router,
  pattern: String,
  p1: Param(a),
  p2: Param(b),
  p3: Param(c),
  handler: fn(radiant_request.Req, a, b, c) -> Response(BitArray),
) -> Router {
  typed3(router, Delete, pattern, p1, p2, p3, handler)
}

pub fn get4(
  router: Router,
  pattern: String,
  p1: Param(a),
  p2: Param(b),
  p3: Param(c),
  p4: Param(d),
  handler: fn(radiant_request.Req, a, b, c, d) -> Response(BitArray),
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
  handler: fn(radiant_request.Req, a, b, c, d) -> Response(BitArray),
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
  handler: fn(radiant_request.Req, a, b, c, d) -> Response(BitArray),
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
  handler: fn(radiant_request.Req, a, b, c, d) -> Response(BitArray),
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
  handler: fn(radiant_request.Req, a, b, c, d) -> Response(BitArray),
) -> Router {
  typed4(router, Delete, pattern, p1, p2, p3, p4, handler)
}

pub fn get5(
  router: Router,
  pattern: String,
  p1: Param(a),
  p2: Param(b),
  p3: Param(c),
  p4: Param(d),
  p5: Param(e),
  handler: fn(radiant_request.Req, a, b, c, d, e) -> Response(BitArray),
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
  handler: fn(radiant_request.Req, a, b, c, d, e) -> Response(BitArray),
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
  handler: fn(radiant_request.Req, a, b, c, d, e) -> Response(BitArray),
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
  handler: fn(radiant_request.Req, a, b, c, d, e) -> Response(BitArray),
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
  handler: fn(radiant_request.Req, a, b, c, d, e) -> Response(BitArray),
) -> Router {
  typed5(router, Delete, pattern, p1, p2, p3, p4, p5, handler)
}

pub fn get6(
  router: Router,
  pattern: String,
  p1: Param(a),
  p2: Param(b),
  p3: Param(c),
  p4: Param(d),
  p5: Param(e),
  p6: Param(f),
  handler: fn(radiant_request.Req, a, b, c, d, e, f) -> Response(BitArray),
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
  handler: fn(radiant_request.Req, a, b, c, d, e, f) -> Response(BitArray),
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
  handler: fn(radiant_request.Req, a, b, c, d, e, f) -> Response(BitArray),
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
  handler: fn(radiant_request.Req, a, b, c, d, e, f) -> Response(BitArray),
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
  handler: fn(radiant_request.Req, a, b, c, d, e, f) -> Response(BitArray),
) -> Router {
  typed6(router, Delete, pattern, p1, p2, p3, p4, p5, p6, handler)
}

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

pub fn mount(router: Router, prefix: String, sub_router: Router) -> Router {
  let prefix_segs = ipath.parse(prefix)
  let sub_routes = tree.to_routes(sub_router.tree)

  list.fold(sub_routes, router, fn(acc_router, r) {
    let #(method, segments, handler) = r

    let with_middlewares =
      list.fold(sub_router.middlewares, handler, fn(h, mw) { mw(h) })

    let full_segments = list.append(prefix_segs, segments)
    let new_tree =
      tree.insert(acc_router.tree, method, full_segments, with_middlewares)
    Router(..acc_router, tree: new_tree)
  })
}

pub fn handle(router: Router, req: Request(BitArray)) -> Response(BitArray) {
  let dispatch = fn(r: radiant_request.Req) -> Response(BitArray) {
    let segments = ipath.split(radiant_request.req_path(r))
    case tree.match(router.tree, radiant_request.method(r), segments) {
      Ok(#(handler, params)) -> {
        let resp = handler(radiant_request.with_params(r, params))
        case radiant_request.method(r) {
          Head -> Response(..resp, body: <<>>)
          _ -> resp
        }
      }
      Error(Nil) -> {
        let head_result = case radiant_request.method(r) {
          Head ->
            case tree.match(router.tree, Get, segments) {
              Ok(#(handler, params)) ->
                Ok(handler(
                  r
                  |> radiant_request.with_params(params)
                  |> radiant_request.with_method(Get),
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
                radiant_response.method_not_allowed(
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

  let final_handler =
    list.fold(router.middlewares, dispatch, fn(handler, mw) { mw(handler) })
  final_handler(radiant_request.from_request(req))
}

pub fn handle_with(
  router: Router,
  req: Request(anything),
  body: BitArray,
) -> Response(BitArray) {
  handle(router, request.set_body(req, body))
}

pub fn any(
  router: Router,
  pattern: String,
  handler: fn(radiant_request.Req) -> Response(BitArray),
) -> Router {
  [Get, Post, Head, Put, Delete, Trace, Connect, Options, Patch, query_method]
  |> list.fold(router, fn(r, m) { add_route(r, m, pattern, handler) })
}

pub fn routes(router: Router) -> List(#(Method, String)) {
  tree.to_routes(router.tree)
  |> list.map(fn(r) {
    let #(method, segments, _handler) = r
    #(method, segments_to_pattern(segments))
  })
}

pub fn path_for(
  pattern: String,
  params: List(#(String, String)),
) -> Result(String, radiant_request.RadiantError) {
  let segments = ipath.parse(pattern)
  let lookup = dict.from_list(params)
  use parts <- result.try(
    list.try_map(segments, fn(seg) {
      case seg {
        ipath.Literal(s) -> Ok(s)
        ipath.Capture(name, _) ->
          dict.get(lookup, name)
          |> result.replace_error(radiant_request.MissingPathParam(name))
          |> result.map(uri.percent_encode)
        ipath.Wildcard(name) ->
          dict.get(lookup, name)
          |> result.replace_error(radiant_request.MissingPathParam(name))
          |> result.map(fn(value) {
            value
            |> string.split("/")
            |> list.map(uri.percent_encode)
            |> string.join("/")
          })
      }
    }),
  )
  case parts {
    [] -> Ok("/")
    _ -> Ok("/" <> string.join(parts, "/"))
  }
}

pub fn path_for1(
  pattern: String,
  p1: Param(a),
  v1: a,
) -> Result(String, radiant_request.RadiantError) {
  path_for(pattern, [#(p1.name, p1.to_string(v1))])
}

pub fn path_for2(
  pattern: String,
  p1: Param(a),
  v1: a,
  p2: Param(b),
  v2: b,
) -> Result(String, radiant_request.RadiantError) {
  path_for(pattern, [#(p1.name, p1.to_string(v1)), #(p2.name, p2.to_string(v2))])
}

pub fn path_for3(
  pattern: String,
  p1: Param(a),
  v1: a,
  p2: Param(b),
  v2: b,
  p3: Param(c),
  v3: c,
) -> Result(String, radiant_request.RadiantError) {
  path_for(pattern, [
    #(p1.name, p1.to_string(v1)),
    #(p2.name, p2.to_string(v2)),
    #(p3.name, p3.to_string(v3)),
  ])
}

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
) -> Result(String, radiant_request.RadiantError) {
  path_for(pattern, [
    #(p1.name, p1.to_string(v1)),
    #(p2.name, p2.to_string(v2)),
    #(p3.name, p3.to_string(v3)),
    #(p4.name, p4.to_string(v4)),
  ])
}

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
) -> Result(String, radiant_request.RadiantError) {
  path_for(pattern, [
    #(p1.name, p1.to_string(v1)),
    #(p2.name, p2.to_string(v2)),
    #(p3.name, p3.to_string(v3)),
    #(p4.name, p4.to_string(v4)),
    #(p5.name, p5.to_string(v5)),
  ])
}

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
) -> Result(String, radiant_request.RadiantError) {
  path_for(pattern, [
    #(p1.name, p1.to_string(v1)),
    #(p2.name, p2.to_string(v2)),
    #(p3.name, p3.to_string(v3)),
    #(p4.name, p4.to_string(v4)),
    #(p5.name, p5.to_string(v5)),
    #(p6.name, p6.to_string(v6)),
  ])
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

fn add_route(
  router: Router,
  method: Method,
  pattern: String,
  handler: fn(radiant_request.Req) -> Response(BitArray),
) -> Router {
  add_route_raw(router, method, ipath.parse(pattern), handler)
}

fn add_route_raw(
  router: Router,
  method: Method,
  segments: List(ipath.Segment),
  handler: fn(radiant_request.Req) -> Response(BitArray),
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

fn parse_param(req: radiant_request.Req, p: Param(a)) -> Result(a, Nil) {
  case radiant_request.str_param(req, p.name) {
    Ok(value) -> p.parse(value)
    Error(_) -> Error(Nil)
  }
}

fn typed1(
  router: Router,
  method: Method,
  pattern: String,
  p1: Param(a),
  handler: fn(radiant_request.Req, a) -> Response(BitArray),
) -> Router {
  let raw = ipath.parse(pattern)
  validate_param(p1, raw, pattern)
  let segments = apply_param_type(raw, p1)
  let wrapped = fn(req: radiant_request.Req) -> Response(BitArray) {
    let assert Ok(v1) = parse_param(req, p1)
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
  handler: fn(radiant_request.Req, a, b) -> Response(BitArray),
) -> Router {
  let raw = ipath.parse(pattern)
  validate_param(p1, raw, pattern)
  validate_param(p2, raw, pattern)
  let segments = raw |> apply_param_type(p1) |> apply_param_type(p2)
  let wrapped = fn(req: radiant_request.Req) -> Response(BitArray) {
    let assert Ok(v1) = parse_param(req, p1)
    let assert Ok(v2) = parse_param(req, p2)
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
  handler: fn(radiant_request.Req, a, b, c) -> Response(BitArray),
) -> Router {
  let raw = ipath.parse(pattern)
  validate_param(p1, raw, pattern)
  validate_param(p2, raw, pattern)
  validate_param(p3, raw, pattern)
  let segments =
    raw |> apply_param_type(p1) |> apply_param_type(p2) |> apply_param_type(p3)
  let wrapped = fn(req: radiant_request.Req) -> Response(BitArray) {
    let assert Ok(v1) = parse_param(req, p1)
    let assert Ok(v2) = parse_param(req, p2)
    let assert Ok(v3) = parse_param(req, p3)
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
  handler: fn(radiant_request.Req, a, b, c, d) -> Response(BitArray),
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
  let wrapped = fn(req: radiant_request.Req) -> Response(BitArray) {
    let assert Ok(v1) = parse_param(req, p1)
    let assert Ok(v2) = parse_param(req, p2)
    let assert Ok(v3) = parse_param(req, p3)
    let assert Ok(v4) = parse_param(req, p4)
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
  handler: fn(radiant_request.Req, a, b, c, d, e) -> Response(BitArray),
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
  let wrapped = fn(req: radiant_request.Req) -> Response(BitArray) {
    let assert Ok(v1) = parse_param(req, p1)
    let assert Ok(v2) = parse_param(req, p2)
    let assert Ok(v3) = parse_param(req, p3)
    let assert Ok(v4) = parse_param(req, p4)
    let assert Ok(v5) = parse_param(req, p5)
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
  handler: fn(radiant_request.Req, a, b, c, d, e, f) -> Response(BitArray),
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
  let wrapped = fn(req: radiant_request.Req) -> Response(BitArray) {
    let assert Ok(v1) = parse_param(req, p1)
    let assert Ok(v2) = parse_param(req, p2)
    let assert Ok(v3) = parse_param(req, p3)
    let assert Ok(v4) = parse_param(req, p4)
    let assert Ok(v5) = parse_param(req, p5)
    let assert Ok(v6) = parse_param(req, p6)
    handler(req, v1, v2, v3, v4, v5, v6)
  }
  add_route_raw(router, method, segments, wrapped)
}
