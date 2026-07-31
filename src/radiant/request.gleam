//// Request accessors, context keys, and request errors.

import gleam/bit_array
import gleam/dict.{type Dict}
import gleam/dynamic
import gleam/float
import gleam/http.{type Method}
import gleam/http/request.{type Request, Request}
import gleam/int
import gleam/list
import gleam/option.{None, Some}
import gleam/result
import gleam/uri

/// Opaque request wrapper with the original request, path params, and typed context.
pub opaque type Req {
  Req(
    request: Request(BitArray),
    params: Dict(String, String),
    context: Dict(String, dynamic.Dynamic),
  )
}

/// A typed key for the request context.
pub opaque type Key(a) {
  Key(String)
}

/// Errors returned by request and context accessors.
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

/// Low-level helper used by `radiant/router` to wrap an HTTP request.
pub fn from_request(request: Request(BitArray)) -> Req {
  Req(request: request, params: dict.new(), context: dict.new())
}

/// Low-level helper used by `radiant/router` to attach extracted path params.
pub fn with_params(req: Req, params: Dict(String, String)) -> Req {
  Req(..req, params: params)
}

/// Low-level helper used by `radiant/router` for HEAD-to-GET dispatch.
pub fn with_method(req: Req, method: Method) -> Req {
  Req(..req, request: Request(..req.request, method: method))
}

/// Create a typed context key.
pub fn key(name: String) -> Key(a) {
  Key(name)
}

/// Create a typed context key with an explicit namespace.
pub fn key_named(namespace: String, name: String) -> Key(a) {
  Key(namespace <> ":" <> name)
}

/// The request HTTP method.
pub fn method(req: Req) -> Method {
  req.request.method
}

/// The request path.
pub fn req_path(req: Req) -> String {
  req.request.path
}

/// Get a request header by key.
pub fn header(req: Req, key: String) -> Result(String, RadiantError) {
  request.get_header(req.request, key)
  |> result.replace_error(MissingHeader(key))
}

/// All request headers.
pub fn headers(req: Req) -> List(#(String, String)) {
  req.request.headers
}

/// The raw request body.
pub fn body(req: Req) -> BitArray {
  req.request.body
}

/// The request body decoded as UTF-8 text.
pub fn text_body(req: Req) -> Result(String, RadiantError) {
  bit_array.to_string(req.request.body)
  |> result.replace_error(InvalidUtf8Body)
}

/// Extract a path parameter as String.
pub fn str_param(req: Req, name: String) -> Result(String, RadiantError) {
  dict.get(req.params, name)
  |> result.replace_error(MissingPathParam(name))
}

/// Extract a path parameter as Int.
pub fn int_param(req: Req, name: String) -> Result(Int, RadiantError) {
  case dict.get(req.params, name) {
    Error(_) -> Error(MissingPathParam(name))
    Ok(value) ->
      case int.parse(value) {
        Ok(parsed) -> Ok(parsed)
        Error(_) -> Error(InvalidIntParam(name, value))
      }
  }
}

/// Get a single query parameter by key.
pub fn query(req: Req, key: String) -> Result(String, RadiantError) {
  case req.request.query {
    None -> Error(MissingQuery(key))
    Some(raw) ->
      case uri.parse_query(raw) {
        Ok(pairs) ->
          pairs
          |> list.key_find(key)
          |> result.replace_error(MissingQuery(key))
        Error(_) -> Error(MalformedQuery(raw))
      }
  }
}

/// All query parameters.
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
pub fn query_int(req: Req, key: String) -> Result(Int, RadiantError) {
  case query(req, key) {
    Error(error) -> Error(error)
    Ok(value) ->
      case int.parse(value) {
        Ok(parsed) -> Ok(parsed)
        Error(_) -> Error(InvalidIntQuery(key, value))
      }
  }
}

/// Get a query parameter parsed as Float.
pub fn query_float(req: Req, key: String) -> Result(Float, RadiantError) {
  case query(req, key) {
    Error(error) -> Error(error)
    Ok(value) ->
      case float.parse(value) {
        Ok(parsed) -> Ok(parsed)
        Error(_) -> Error(InvalidFloatQuery(key, value))
      }
  }
}

/// Get a query parameter parsed as Bool.
pub fn query_bool(req: Req, key: String) -> Result(Bool, RadiantError) {
  case query(req, key) {
    Ok("true") | Ok("1") -> Ok(True)
    Ok("false") | Ok("0") -> Ok(False)
    Ok(value) -> Error(InvalidBoolQuery(key, value))
    Error(error) -> Error(error)
  }
}

/// Access the underlying `Request(BitArray)`.
pub fn original(req: Req) -> Request(BitArray) {
  req.request
}

/// Store a typed value in the request context.
pub fn set_context(req: Req, k: Key(a), value: a) -> Req {
  let Key(name) = k
  Req(..req, context: dict.insert(req.context, name, unsafe_coerce(value)))
}

/// Retrieve a typed value from the request context.
pub fn get_context(req: Req, k: Key(a)) -> Result(a, RadiantError) {
  let Key(name) = k
  case dict.get(req.context, name) {
    Ok(dyn) -> Ok(unsafe_coerce(dyn))
    Error(_) -> Error(MissingContext(name))
  }
}

@external(erlang, "gleam_stdlib", "identity")
@external(javascript, "../gleam_stdlib.mjs", "identity")
fn unsafe_coerce(a: a) -> b
