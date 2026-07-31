//// Built-in middleware and related config types.

import exception
import gleam/dynamic/decode
import gleam/http.{type Method, Delete, Get, Options, Patch, Post, Put}
import gleam/http/response.{type Response}
import gleam/int
import gleam/json as gjson
import gleam/list
import gleam/result
import gleam/string
import radiant/request
import radiant/response as radiant_response
import radiant/router

pub type Middleware =
  router.Middleware

/// A swappable interface for file system operations.
pub type FileSystem {
  FileSystem(
    read_bits: fn(String) -> Result(BitArray, Nil),
    is_file: fn(String) -> Bool,
  )
}

/// Configuration for the CORS middleware.
pub type CorsConfig {
  CorsConfig(
    origins: List(String),
    methods: List(Method),
    headers: List(String),
    max_age: Int,
  )
}

pub fn default_cors() -> CorsConfig {
  CorsConfig(
    origins: ["*"],
    methods: [Get, Post, Put, Patch, Delete],
    headers: ["content-type", "authorization"],
    max_age: 86_400,
  )
}

pub fn cors(config: CorsConfig) -> Middleware {
  fn(next) {
    fn(req) {
      let origin = request.header(req, "origin") |> result.unwrap("")
      let allowed =
        origin != ""
        && {
          list.contains(config.origins, "*")
          || list.contains(config.origins, origin)
        }
      let preflight =
        request.method(req) == Options
        && allowed
        && {
          case request.header(req, "access-control-request-method") {
            Ok(_) -> True
            Error(_) -> False
          }
        }
      case preflight {
        True ->
          radiant_response.no_content()
          |> radiant_response.with_header("access-control-allow-origin", origin)
          |> radiant_response.with_header("vary", "origin")
          |> radiant_response.with_header(
            "access-control-allow-methods",
            config.methods
              |> list.map(http.method_to_string)
              |> string.join(", "),
          )
          |> radiant_response.with_header(
            "access-control-allow-headers",
            string.join(config.headers, ", "),
          )
          |> radiant_response.with_header(
            "access-control-max-age",
            int.to_string(config.max_age),
          )
        False -> {
          let resp = next(req)
          case allowed {
            True ->
              resp
              |> radiant_response.with_header(
                "access-control-allow-origin",
                origin,
              )
              |> radiant_response.with_header("vary", "origin")
            False -> resp
          }
        }
      }
    }
  }
}

pub fn log(logger: fn(String) -> a) -> Middleware {
  fn(next) {
    fn(req) {
      let m = http.method_to_string(request.method(req))
      let p = request.req_path(req)
      logger(m <> " " <> p)
      let resp: Response(BitArray) = next(req)
      logger(m <> " " <> p <> " → " <> int.to_string(resp.status))
      resp
    }
  }
}

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

pub fn json_body(
  key: request.Key(a),
  decoder: decode.Decoder(a),
) -> Middleware {
  fn(next) {
    fn(req) {
      case request.body(req) {
        <<>> -> next(req)
        _ ->
          case request.text_body(req) {
            Ok(b) ->
              case gjson.parse(b, decoder) {
                Ok(val) -> next(request.set_context(req, key, val))
                Error(_) -> radiant_response.bad_request()
              }
            Error(_) -> radiant_response.bad_request()
          }
      }
    }
  }
}

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
      let path = request.req_path(req)
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
