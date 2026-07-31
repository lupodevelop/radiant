//// Backwards-compatible facade for `import radiant`.
//// The implementation is split across focused `radiant/*` modules; this
//// module remains the compatibility surface for application code.

import exception
import gleam/dynamic/decode
import gleam/http.{type Method}
import gleam/http/request.{type Request}
import gleam/http/response.{type Response}
import gleam/result
import radiant/context as radiant_context
import radiant/middleware as radiant_middleware
import radiant/request as radiant_request
import radiant/response as radiant_response
import radiant/router as radiant_router
import radiant/testing as radiant_testing

pub type Router =
  radiant_router.Router

pub type Middleware =
  radiant_router.Middleware

pub type FileSystem {
  FileSystem(
    read_bits: fn(String) -> Result(BitArray, Nil),
    is_file: fn(String) -> Bool,
  )
}

pub type Req =
  radiant_request.Req

pub type Key(a) =
  radiant_request.Key(a)

pub type Param(a) =
  radiant_router.Param(a)

pub type TestRequest =
  radiant_testing.TestRequest

pub type RadiantError {
  MissingHeader(String)
  InvalidUtf8Body
  MissingPathParam(String)
  InvalidIntParam(String, String)
  MissingQuery(String)
  InvalidIntQuery(String, String)
  InvalidFloatQuery(String, String)
  InvalidBoolQuery(String, String)
  MalformedQuery(String)
  MissingContext(String)
}

pub type CorsConfig {
  CorsConfig(
    origins: List(String),
    methods: List(Method),
    headers: List(String),
    max_age: Int,
  )
}

pub const query_method: Method = radiant_router.query_method

pub fn int(name: String) -> Param(Int) {
  radiant_router.int(name)
}

pub fn str(name: String) -> Param(String) {
  radiant_router.str(name)
}

pub fn key(name: String) -> Key(a) {
  radiant_request.key(name)
}

pub fn key_named(namespace: String, name: String) -> Key(a) {
  radiant_request.key_named(namespace, name)
}

pub fn new() -> Router {
  radiant_router.new()
}

pub fn fallback(
  router: Router,
  handler: fn(Req) -> Response(BitArray),
) -> Router {
  radiant_router.fallback(router, handler)
}

pub fn middleware(router: Router, mw: Middleware) -> Router {
  radiant_router.middleware(router, mw)
}

pub fn wrap(
  mw: Middleware,
  handler: fn(Req) -> Response(BitArray),
) -> fn(Req) -> Response(BitArray) {
  radiant_router.wrap(mw, handler)
}

pub fn get(
  router: Router,
  pattern: String,
  handler: fn(Req) -> Response(BitArray),
) -> Router {
  radiant_router.get(router, pattern, handler)
}

pub fn post(
  router: Router,
  pattern: String,
  handler: fn(Req) -> Response(BitArray),
) -> Router {
  radiant_router.post(router, pattern, handler)
}

pub fn put(
  router: Router,
  pattern: String,
  handler: fn(Req) -> Response(BitArray),
) -> Router {
  radiant_router.put(router, pattern, handler)
}

pub fn patch(
  router: Router,
  pattern: String,
  handler: fn(Req) -> Response(BitArray),
) -> Router {
  radiant_router.patch(router, pattern, handler)
}

pub fn delete(
  router: Router,
  pattern: String,
  handler: fn(Req) -> Response(BitArray),
) -> Router {
  radiant_router.delete(router, pattern, handler)
}

pub fn options(
  router: Router,
  pattern: String,
  handler: fn(Req) -> Response(BitArray),
) -> Router {
  radiant_router.options(router, pattern, handler)
}

/// Register a route for any HTTP method.
pub fn route(
  router: Router,
  method: Method,
  pattern: String,
  handler: fn(Req) -> Response(BitArray),
) -> Router {
  radiant_router.route(router, method, pattern, handler)
}

pub fn query_route(
  router: Router,
  pattern: String,
  handler: fn(Req) -> Response(BitArray),
) -> Router {
  radiant_router.query_route(router, pattern, handler)
}

pub fn get1(
  router: Router,
  pattern: String,
  p1: Param(a),
  handler: fn(Req, a) -> Response(BitArray),
) -> Router {
  radiant_router.get1(router, pattern, p1, handler)
}

pub fn post1(
  router: Router,
  pattern: String,
  p1: Param(a),
  handler: fn(Req, a) -> Response(BitArray),
) -> Router {
  radiant_router.post1(router, pattern, p1, handler)
}

pub fn put1(
  router: Router,
  pattern: String,
  p1: Param(a),
  handler: fn(Req, a) -> Response(BitArray),
) -> Router {
  radiant_router.put1(router, pattern, p1, handler)
}

pub fn patch1(
  router: Router,
  pattern: String,
  p1: Param(a),
  handler: fn(Req, a) -> Response(BitArray),
) -> Router {
  radiant_router.patch1(router, pattern, p1, handler)
}

pub fn delete1(
  router: Router,
  pattern: String,
  p1: Param(a),
  handler: fn(Req, a) -> Response(BitArray),
) -> Router {
  radiant_router.delete1(router, pattern, p1, handler)
}

pub fn get2(
  router: Router,
  pattern: String,
  p1: Param(a),
  p2: Param(b),
  handler: fn(Req, a, b) -> Response(BitArray),
) -> Router {
  radiant_router.get2(router, pattern, p1, p2, handler)
}

pub fn post2(
  router: Router,
  pattern: String,
  p1: Param(a),
  p2: Param(b),
  handler: fn(Req, a, b) -> Response(BitArray),
) -> Router {
  radiant_router.post2(router, pattern, p1, p2, handler)
}

pub fn put2(
  router: Router,
  pattern: String,
  p1: Param(a),
  p2: Param(b),
  handler: fn(Req, a, b) -> Response(BitArray),
) -> Router {
  radiant_router.put2(router, pattern, p1, p2, handler)
}

pub fn patch2(
  router: Router,
  pattern: String,
  p1: Param(a),
  p2: Param(b),
  handler: fn(Req, a, b) -> Response(BitArray),
) -> Router {
  radiant_router.patch2(router, pattern, p1, p2, handler)
}

pub fn delete2(
  router: Router,
  pattern: String,
  p1: Param(a),
  p2: Param(b),
  handler: fn(Req, a, b) -> Response(BitArray),
) -> Router {
  radiant_router.delete2(router, pattern, p1, p2, handler)
}

pub fn get3(
  router: Router,
  pattern: String,
  p1: Param(a),
  p2: Param(b),
  p3: Param(c),
  handler: fn(Req, a, b, c) -> Response(BitArray),
) -> Router {
  radiant_router.get3(router, pattern, p1, p2, p3, handler)
}

pub fn post3(
  router: Router,
  pattern: String,
  p1: Param(a),
  p2: Param(b),
  p3: Param(c),
  handler: fn(Req, a, b, c) -> Response(BitArray),
) -> Router {
  radiant_router.post3(router, pattern, p1, p2, p3, handler)
}

pub fn put3(
  router: Router,
  pattern: String,
  p1: Param(a),
  p2: Param(b),
  p3: Param(c),
  handler: fn(Req, a, b, c) -> Response(BitArray),
) -> Router {
  radiant_router.put3(router, pattern, p1, p2, p3, handler)
}

pub fn patch3(
  router: Router,
  pattern: String,
  p1: Param(a),
  p2: Param(b),
  p3: Param(c),
  handler: fn(Req, a, b, c) -> Response(BitArray),
) -> Router {
  radiant_router.patch3(router, pattern, p1, p2, p3, handler)
}

pub fn delete3(
  router: Router,
  pattern: String,
  p1: Param(a),
  p2: Param(b),
  p3: Param(c),
  handler: fn(Req, a, b, c) -> Response(BitArray),
) -> Router {
  radiant_router.delete3(router, pattern, p1, p2, p3, handler)
}

pub fn get4(
  router: Router,
  pattern: String,
  p1: Param(a),
  p2: Param(b),
  p3: Param(c),
  p4: Param(d),
  handler: fn(Req, a, b, c, d) -> Response(BitArray),
) -> Router {
  radiant_router.get4(router, pattern, p1, p2, p3, p4, handler)
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
  radiant_router.post4(router, pattern, p1, p2, p3, p4, handler)
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
  radiant_router.put4(router, pattern, p1, p2, p3, p4, handler)
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
  radiant_router.patch4(router, pattern, p1, p2, p3, p4, handler)
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
  radiant_router.delete4(router, pattern, p1, p2, p3, p4, handler)
}

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
  radiant_router.get5(router, pattern, p1, p2, p3, p4, p5, handler)
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
  radiant_router.post5(router, pattern, p1, p2, p3, p4, p5, handler)
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
  radiant_router.put5(router, pattern, p1, p2, p3, p4, p5, handler)
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
  radiant_router.patch5(router, pattern, p1, p2, p3, p4, p5, handler)
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
  radiant_router.delete5(router, pattern, p1, p2, p3, p4, p5, handler)
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
  handler: fn(Req, a, b, c, d, e, f) -> Response(BitArray),
) -> Router {
  radiant_router.get6(router, pattern, p1, p2, p3, p4, p5, p6, handler)
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
  radiant_router.post6(router, pattern, p1, p2, p3, p4, p5, p6, handler)
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
  radiant_router.put6(router, pattern, p1, p2, p3, p4, p5, p6, handler)
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
  radiant_router.patch6(router, pattern, p1, p2, p3, p4, p5, p6, handler)
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
  radiant_router.delete6(router, pattern, p1, p2, p3, p4, p5, p6, handler)
}

pub fn scope(
  router: Router,
  prefix: String,
  builder: fn(Router) -> Router,
) -> Router {
  radiant_router.scope(router, prefix, builder)
}

pub fn mount(router: Router, prefix: String, sub_router: Router) -> Router {
  radiant_router.mount(router, prefix, sub_router)
}

pub fn handle(router: Router, req: Request(BitArray)) -> Response(BitArray) {
  radiant_router.handle(router, req)
}

pub fn handle_with(
  router: Router,
  req: Request(anything),
  body: BitArray,
) -> Response(BitArray) {
  radiant_router.handle_with(router, req, body)
}

pub fn any(
  router: Router,
  pattern: String,
  handler: fn(Req) -> Response(BitArray),
) -> Router {
  radiant_router.any(router, pattern, handler)
}

pub fn routes(router: Router) -> List(#(Method, String)) {
  radiant_router.routes(router)
}

pub fn path_for(
  pattern: String,
  params: List(#(String, String)),
) -> Result(String, RadiantError) {
  radiant_router.path_for(pattern, params)
  |> lift_error
}

pub fn path_for1(
  pattern: String,
  p1: Param(a),
  v1: a,
) -> Result(String, RadiantError) {
  radiant_router.path_for1(pattern, p1, v1)
  |> lift_error
}

pub fn path_for2(
  pattern: String,
  p1: Param(a),
  v1: a,
  p2: Param(b),
  v2: b,
) -> Result(String, RadiantError) {
  radiant_router.path_for2(pattern, p1, v1, p2, v2)
  |> lift_error
}

pub fn path_for3(
  pattern: String,
  p1: Param(a),
  v1: a,
  p2: Param(b),
  v2: b,
  p3: Param(c),
  v3: c,
) -> Result(String, RadiantError) {
  radiant_router.path_for3(pattern, p1, v1, p2, v2, p3, v3)
  |> lift_error
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
) -> Result(String, RadiantError) {
  radiant_router.path_for4(pattern, p1, v1, p2, v2, p3, v3, p4, v4)
  |> lift_error
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
) -> Result(String, RadiantError) {
  radiant_router.path_for5(pattern, p1, v1, p2, v2, p3, v3, p4, v4, p5, v5)
  |> lift_error
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
) -> Result(String, RadiantError) {
  radiant_router.path_for6(
    pattern,
    p1,
    v1,
    p2,
    v2,
    p3,
    v3,
    p4,
    v4,
    p5,
    v5,
    p6,
    v6,
  )
  |> lift_error
}

pub fn method(req: Req) -> Method {
  radiant_request.method(req)
}

pub fn req_path(req: Req) -> String {
  radiant_request.req_path(req)
}

pub fn header(req: Req, key: String) -> Result(String, RadiantError) {
  radiant_request.header(req, key)
  |> lift_error
}

pub fn headers(req: Req) -> List(#(String, String)) {
  radiant_request.headers(req)
}

pub fn body(req: Req) -> BitArray {
  radiant_request.body(req)
}

pub fn text_body(req: Req) -> Result(String, RadiantError) {
  radiant_request.text_body(req)
  |> lift_error
}

pub fn str_param(req: Req, name: String) -> Result(String, RadiantError) {
  radiant_request.str_param(req, name)
  |> lift_error
}

pub fn int_param(req: Req, name: String) -> Result(Int, RadiantError) {
  radiant_request.int_param(req, name)
  |> lift_error
}

pub fn query(req: Req, key: String) -> Result(String, RadiantError) {
  radiant_request.query(req, key)
  |> lift_error
}

pub fn queries(req: Req) -> List(#(String, String)) {
  radiant_request.queries(req)
}

pub fn query_int(req: Req, key: String) -> Result(Int, RadiantError) {
  radiant_request.query_int(req, key)
  |> lift_error
}

pub fn query_float(req: Req, key: String) -> Result(Float, RadiantError) {
  radiant_request.query_float(req, key)
  |> lift_error
}

pub fn query_bool(req: Req, key: String) -> Result(Bool, RadiantError) {
  radiant_request.query_bool(req, key)
  |> lift_error
}

pub fn original(req: Req) -> Request(BitArray) {
  radiant_request.original(req)
}

pub fn set_context(req: Req, k: Key(a), value: a) -> Req {
  radiant_context.set_context(req, k, value)
}

pub fn get_context(req: Req, k: Key(a)) -> Result(a, RadiantError) {
  radiant_context.get_context(req, k)
  |> lift_error
}

pub fn response(status: Int, body_text: String) -> Response(BitArray) {
  radiant_response.response(status, body_text)
}

pub fn ok(body_text: String) -> Response(BitArray) {
  radiant_response.ok(body_text)
}

pub fn created(body_text: String) -> Response(BitArray) {
  radiant_response.created(body_text)
}

pub fn no_content() -> Response(BitArray) {
  radiant_response.no_content()
}

pub fn not_found() -> Response(BitArray) {
  radiant_response.not_found()
}

pub fn bad_request() -> Response(BitArray) {
  radiant_response.bad_request()
}

pub fn unauthorized() -> Response(BitArray) {
  radiant_response.unauthorized()
}

pub fn forbidden() -> Response(BitArray) {
  radiant_response.forbidden()
}

pub fn method_not_allowed(allowed: String) -> Response(BitArray) {
  radiant_response.method_not_allowed(allowed)
}

pub fn unprocessable_entity() -> Response(BitArray) {
  radiant_response.unprocessable_entity()
}

pub fn internal_server_error() -> Response(BitArray) {
  radiant_response.internal_server_error()
}

pub fn bad_request_with(body_text: String) -> Response(BitArray) {
  radiant_response.bad_request_with(body_text)
}

pub fn unauthorized_with(body_text: String) -> Response(BitArray) {
  radiant_response.unauthorized_with(body_text)
}

pub fn forbidden_with(body_text: String) -> Response(BitArray) {
  radiant_response.forbidden_with(body_text)
}

pub fn not_found_with(body_text: String) -> Response(BitArray) {
  radiant_response.not_found_with(body_text)
}

pub fn unprocessable_entity_with(body_text: String) -> Response(BitArray) {
  radiant_response.unprocessable_entity_with(body_text)
}

pub fn internal_server_error_with(body_text: String) -> Response(BitArray) {
  radiant_response.internal_server_error_with(body_text)
}

pub fn json_error(status: Int, message: String) -> Response(BitArray) {
  radiant_response.json_error(status, message)
}

/// Return a concise, stable message for a `RadiantError`.
pub fn error_message(error: RadiantError) -> String {
  case error {
    MissingHeader(name) -> "missing header: " <> name
    InvalidUtf8Body -> "request body is not valid UTF-8"
    MissingPathParam(name) -> "missing path parameter: " <> name
    InvalidIntParam(name, value) ->
      "path parameter '" <> name <> "' is not an integer: " <> value
    MissingQuery(name) -> "missing query parameter: " <> name
    InvalidIntQuery(name, value) ->
      "query parameter '" <> name <> "' is not an integer: " <> value
    InvalidFloatQuery(name, value) ->
      "query parameter '" <> name <> "' is not a float: " <> value
    InvalidBoolQuery(name, value) ->
      "query parameter '" <> name <> "' is not a boolean: " <> value
    MalformedQuery(_) -> "malformed query string"
    MissingContext(name) -> "missing context value: " <> name
  }
}

/// Build a JSON error response from a detailed `RadiantError`.
pub fn json_error_from(status: Int, error: RadiantError) -> Response(BitArray) {
  json_error(status, error_message(error))
}

pub fn redirect(uri: String) -> Response(BitArray) {
  radiant_response.redirect(uri)
}

pub fn json(body_text: String) -> Response(BitArray) {
  radiant_response.json(body_text)
}

pub fn html(body_text: String) -> Response(BitArray) {
  radiant_response.html(body_text)
}

pub fn with_header(
  resp: Response(BitArray),
  key: String,
  value: String,
) -> Response(BitArray) {
  radiant_response.with_header(resp, key, value)
}

pub fn default_cors() -> CorsConfig {
  radiant_middleware.default_cors()
  |> from_middleware_cors
}

pub fn cors(config: CorsConfig) -> Middleware {
  radiant_middleware.cors(to_middleware_cors(config))
}

pub fn log(logger: fn(String) -> a) -> Middleware {
  radiant_middleware.log(logger)
}

pub fn rescue(
  on_error: fn(exception.Exception) -> Response(BitArray),
) -> Middleware {
  radiant_middleware.rescue(on_error)
}

pub fn json_body(key: Key(a), decoder: decode.Decoder(a)) -> Middleware {
  radiant_middleware.json_body(key, decoder)
}

pub fn serve_static(
  prefix prefix: String,
  from directory: String,
  via fs: FileSystem,
) -> Middleware {
  radiant_middleware.serve_static(
    prefix: prefix,
    from: directory,
    via: to_middleware_fs(fs),
  )
}

pub fn test_request(method: Method, raw_path: String) -> Request(BitArray) {
  radiant_testing.test_request(method, raw_path)
}

pub fn request(method: Method, raw_path: String) -> TestRequest {
  radiant_testing.request(method, raw_path)
}

pub fn with_query(
  test_request: TestRequest,
  key: String,
  value: String,
) -> TestRequest {
  radiant_testing.with_query(test_request, key, value)
}

pub fn with_request_header(
  test_request: TestRequest,
  key: String,
  value: String,
) -> TestRequest {
  radiant_testing.with_request_header(test_request, key, value)
}

pub fn with_request_body(
  test_request: TestRequest,
  body: String,
) -> TestRequest {
  radiant_testing.with_request_body(test_request, body)
}

pub fn build(test_request: TestRequest) -> Request(BitArray) {
  radiant_testing.build(test_request)
}

pub fn test_get(raw_path: String) -> Request(BitArray) {
  radiant_testing.test_get(raw_path)
}

pub fn test_post(raw_path: String, body_text: String) -> Request(BitArray) {
  radiant_testing.test_post(raw_path, body_text)
}

pub fn test_put(raw_path: String, body_text: String) -> Request(BitArray) {
  radiant_testing.test_put(raw_path, body_text)
}

pub fn test_patch(raw_path: String, body_text: String) -> Request(BitArray) {
  radiant_testing.test_patch(raw_path, body_text)
}

pub fn test_delete(raw_path: String) -> Request(BitArray) {
  radiant_testing.test_delete(raw_path)
}

pub fn test_head(raw_path: String) -> Request(BitArray) {
  radiant_testing.test_head(raw_path)
}

pub fn test_options(raw_path: String) -> Request(BitArray) {
  radiant_testing.test_options(raw_path)
}

pub fn should_have_status(
  resp: Response(BitArray),
  expected: Int,
) -> Response(BitArray) {
  radiant_testing.should_have_status(resp, expected)
}

pub fn should_have_body(
  resp: Response(BitArray),
  expected: String,
) -> Response(BitArray) {
  radiant_testing.should_have_body(resp, expected)
}

pub fn should_have_header(
  resp: Response(BitArray),
  name: String,
  expected: String,
) -> Response(BitArray) {
  radiant_testing.should_have_header(resp, name, expected)
}

pub fn should_have_json_body(
  resp: Response(BitArray),
  decoder: decode.Decoder(a),
) -> a {
  radiant_testing.should_have_json_body(resp, decoder)
}

fn lift_error(
  value: Result(a, radiant_request.RadiantError),
) -> Result(a, RadiantError) {
  result.map_error(value, to_facade_error)
}

fn to_facade_error(error: radiant_request.RadiantError) -> RadiantError {
  case error {
    radiant_request.MissingHeader(value) -> MissingHeader(value)
    radiant_request.InvalidUtf8Body -> InvalidUtf8Body
    radiant_request.MissingPathParam(value) -> MissingPathParam(value)
    radiant_request.InvalidIntParam(name, value) -> InvalidIntParam(name, value)
    radiant_request.MissingQuery(value) -> MissingQuery(value)
    radiant_request.InvalidIntQuery(name, value) -> InvalidIntQuery(name, value)
    radiant_request.InvalidFloatQuery(name, value) ->
      InvalidFloatQuery(name, value)
    radiant_request.InvalidBoolQuery(name, value) ->
      InvalidBoolQuery(name, value)
    radiant_request.MalformedQuery(value) -> MalformedQuery(value)
    radiant_request.MissingContext(value) -> MissingContext(value)
  }
}

fn from_middleware_cors(config: radiant_middleware.CorsConfig) -> CorsConfig {
  let radiant_middleware.CorsConfig(origins, methods, headers, max_age) = config
  CorsConfig(origins, methods, headers, max_age)
}

fn to_middleware_cors(config: CorsConfig) -> radiant_middleware.CorsConfig {
  let CorsConfig(origins, methods, headers, max_age) = config
  radiant_middleware.CorsConfig(origins, methods, headers, max_age)
}

fn to_middleware_fs(fs: FileSystem) -> radiant_middleware.FileSystem {
  let FileSystem(read_bits, is_file) = fs
  radiant_middleware.FileSystem(read_bits, is_file)
}
