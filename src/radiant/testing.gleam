//// Test request builders and assertions.

import gleam/bit_array
import gleam/dynamic/decode
import gleam/http.{type Method, Delete, Get, Head, Options, Patch, Post, Put}
import gleam/http/request as http_request
import gleam/http/response.{type Response}
import gleam/int
import gleam/json as gjson
import gleam/option.{Some}
import gleam/result
import gleam/string

/// A composable request used by router tests.
pub opaque type TestRequest {
  TestRequest(http_request.Request(BitArray))
}

pub fn request(method: Method, raw_path: String) -> TestRequest {
  TestRequest(test_request(method, raw_path))
}

pub fn with_query(
  test_request: TestRequest,
  key: String,
  value: String,
) -> TestRequest {
  let TestRequest(req) = test_request
  let pairs = http_request.get_query(req) |> result.unwrap([])
  TestRequest(http_request.set_query(req, [#(key, value), ..pairs]))
}

pub fn with_request_header(
  test_request: TestRequest,
  key: String,
  value: String,
) -> TestRequest {
  let TestRequest(req) = test_request
  TestRequest(http_request.set_header(req, key, value))
}

pub fn with_request_body(
  test_request: TestRequest,
  body: String,
) -> TestRequest {
  let TestRequest(req) = test_request
  TestRequest(http_request.set_body(req, <<body:utf8>>))
}

pub fn build(test_request: TestRequest) -> http_request.Request(BitArray) {
  let TestRequest(req) = test_request
  req
}

pub fn test_request(
  method: Method,
  raw_path: String,
) -> http_request.Request(BitArray) {
  case string.split_once(raw_path, on: "?") {
    Ok(#(p, q)) ->
      http_request.new()
      |> http_request.set_method(method)
      |> http_request.set_path(p)
      |> fn(r) { http_request.Request(..r, query: Some(q)) }
      |> http_request.set_body(<<>>)
    Error(Nil) ->
      http_request.new()
      |> http_request.set_method(method)
      |> http_request.set_path(raw_path)
      |> http_request.set_body(<<>>)
  }
}

pub fn test_get(raw_path: String) -> http_request.Request(BitArray) {
  test_request(Get, raw_path)
}

pub fn test_post(
  raw_path: String,
  body_text: String,
) -> http_request.Request(BitArray) {
  test_request(Post, raw_path)
  |> http_request.set_body(<<body_text:utf8>>)
}

pub fn test_put(
  raw_path: String,
  body_text: String,
) -> http_request.Request(BitArray) {
  test_request(Put, raw_path)
  |> http_request.set_body(<<body_text:utf8>>)
}

pub fn test_patch(
  raw_path: String,
  body_text: String,
) -> http_request.Request(BitArray) {
  test_request(Patch, raw_path)
  |> http_request.set_body(<<body_text:utf8>>)
}

pub fn test_delete(raw_path: String) -> http_request.Request(BitArray) {
  test_request(Delete, raw_path)
}

pub fn test_head(raw_path: String) -> http_request.Request(BitArray) {
  test_request(Head, raw_path)
}

pub fn test_options(raw_path: String) -> http_request.Request(BitArray) {
  test_request(Options, raw_path)
}

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
