import gleam/list
import gleam/result
import gleam/string
import gleam/uri

pub type ParamType {
  StringT
  IntT
}

pub type Segment {
  Literal(String)
  Capture(String, ParamType)
  Wildcard(String)
}

/// Split a request path into string segments, decoding percent-encoded characters.
pub fn split(request_path: String) -> List(String) {
  request_path
  |> string.split("/")
  |> list.filter(fn(s) { s != "" })
  |> list.map(fn(s) { uri.percent_decode(s) |> result.unwrap(s) })
}

/// Parse a route pattern like "/users/:id/posts" or "/users/<id:int>" into segments.
/// Supports wildcards: "/static/*rest" captures all remaining segments.
///
/// Panics if a capture or wildcard name is empty.
pub fn parse(pattern: String) -> List(Segment) {
  pattern
  |> string.split("/")
  |> list.filter(fn(s) { s != "" })
  |> list.map(fn(s) {
    case s {
      ":" <> name -> parse_capture(name, pattern)
      "<" <> rest -> parse_bracket_capture(rest, pattern)
      "*" <> name -> {
        case name {
          "" -> panic as { "Radiant: Wildcard name cannot be empty in pattern: " <> pattern }
          _ -> Wildcard(name)
        }
      }
      _ -> Literal(s)
    }
  })
}

fn parse_capture(content: String, full_pattern: String) -> Segment {
  case content {
    "" -> panic as { "Radiant: Capture name cannot be empty in pattern: " <> full_pattern }
    _ -> Capture(content, StringT)
  }
}

fn parse_bracket_capture(rest: String, full_pattern: String) -> Segment {
  case string.ends_with(rest, ">") {
    True -> {
      let content = string.drop_end(rest, 1)
      case string.split_once(content, ":") {
        Ok(#(name, "int")) -> Capture(name, IntT)
        Ok(#(name, "string")) -> Capture(name, StringT)
        Ok(#(_, t)) -> panic as { "Radiant: Unsupported type constraint '" <> t <> "' in pattern: " <> full_pattern }
        Error(Nil) -> parse_capture(content, full_pattern)
      }
    }
    False -> Literal("<" <> rest)
  }
}


