//// Response builders for text, JSON, redirects, and status helpers.

import gleam/http/response.{type Response, Response}
import gleam/json as gjson

/// Build a response with the given status and UTF-8 text body.
pub fn response(status: Int, body_text: String) -> Response(BitArray) {
  Response(
    status:,
    headers: [#("content-type", "text/plain; charset=utf-8")],
    body: <<body_text:utf8>>,
  )
}

pub fn ok(body_text: String) -> Response(BitArray) {
  response(200, body_text)
}

pub fn created(body_text: String) -> Response(BitArray) {
  response(201, body_text)
}

pub fn no_content() -> Response(BitArray) {
  Response(status: 204, headers: [], body: <<>>)
}

pub fn not_found() -> Response(BitArray) {
  response(404, "")
}

pub fn bad_request() -> Response(BitArray) {
  response(400, "")
}

pub fn unauthorized() -> Response(BitArray) {
  response(401, "")
}

pub fn forbidden() -> Response(BitArray) {
  response(403, "")
}

pub fn method_not_allowed(allowed: String) -> Response(BitArray) {
  response(405, "")
  |> with_header("allow", allowed)
}

pub fn unprocessable_entity() -> Response(BitArray) {
  response(422, "")
}

pub fn internal_server_error() -> Response(BitArray) {
  response(500, "")
}

pub fn bad_request_with(body_text: String) -> Response(BitArray) {
  response(400, body_text)
}

pub fn unauthorized_with(body_text: String) -> Response(BitArray) {
  response(401, body_text)
}

pub fn forbidden_with(body_text: String) -> Response(BitArray) {
  response(403, body_text)
}

pub fn not_found_with(body_text: String) -> Response(BitArray) {
  response(404, body_text)
}

pub fn unprocessable_entity_with(body_text: String) -> Response(BitArray) {
  response(422, body_text)
}

pub fn internal_server_error_with(body_text: String) -> Response(BitArray) {
  response(500, body_text)
}

pub fn json_error(status: Int, message: String) -> Response(BitArray) {
  let body = gjson.to_string(gjson.object([#("error", gjson.string(message))]))
  response(status, body)
  |> with_header("content-type", "application/json; charset=utf-8")
}

pub fn redirect(uri: String) -> Response(BitArray) {
  Response(status: 303, headers: [#("location", uri)], body: <<>>)
}

pub fn json(body_text: String) -> Response(BitArray) {
  response(200, body_text)
  |> with_header("content-type", "application/json; charset=utf-8")
}

pub fn html(body_text: String) -> Response(BitArray) {
  response(200, body_text)
  |> with_header("content-type", "text/html; charset=utf-8")
}

pub fn with_header(
  resp: Response(BitArray),
  key: String,
  value: String,
) -> Response(BitArray) {
  response.set_header(resp, key, value)
}
