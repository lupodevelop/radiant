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
/// Panics if:
/// - A capture or wildcard name is empty.
/// - A wildcard appears before the last segment (e.g. `/files/*rest/download`).
/// - Two captures/wildcards in the same pattern share the same name.
pub fn parse(pattern: String) -> List(Segment) {
  let segments =
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
  let _ = check_wildcard_position(segments, pattern)
  let _ = check_duplicate_names(segments, pattern)
  segments
}

fn check_wildcard_position(segments: List(Segment), pattern: String) -> Nil {
  case segments {
    [] -> Nil
    [Wildcard(_), _, ..] ->
      panic as {
        "Radiant: Wildcard must be the last segment in pattern: "
        <> pattern
        <> ". Segments after a wildcard are never reachable."
      }
    [_, ..rest] -> check_wildcard_position(rest, pattern)
  }
}

fn check_duplicate_names(segments: List(Segment), pattern: String) -> Nil {
  let names =
    list.filter_map(segments, fn(seg) {
      case seg {
        Capture(name, _) -> Ok(name)
        Wildcard(name) -> Ok(name)
        Literal(_) -> Error(Nil)
      }
    })
  case find_duplicate(names) {
    Ok(dup) ->
      panic as {
        "Radiant: Duplicate capture name '"
        <> dup
        <> "' in pattern: "
        <> pattern
        <> ". Each capture and wildcard must have a distinct name."
      }
    Error(_) -> Nil
  }
}

fn find_duplicate(names: List(String)) -> Result(String, Nil) {
  case names {
    [] -> Error(Nil)
    [name, ..rest] ->
      case list.contains(rest, name) {
        True -> Ok(name)
        False -> find_duplicate(rest)
      }
  }
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


