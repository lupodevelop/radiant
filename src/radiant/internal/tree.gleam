import gleam/dict.{type Dict}
import gleam/http.{type Method}
import gleam/int
import gleam/list
import gleam/option.{type Option, None, Some}
import gleam/string
import radiant/internal/path as ipath

pub type Node(handler) {
  Node(
    handlers: Dict(Method, handler),
    literals: Dict(String, Node(handler)),
    captures: List(#(String, ipath.ParamType, Node(handler))),
    wildcard: Option(#(String, Node(handler))),
  )
}

pub fn new() -> Node(handler) {
  Node(handlers: dict.new(), literals: dict.new(), captures: [], wildcard: None)
}

// ---------------------------------------------------------------------------
// Insert
// ---------------------------------------------------------------------------

pub fn insert(
  node: Node(handler),
  method: Method,
  segments: List(ipath.Segment),
  handler: handler,
) -> Node(handler) {
  case segments {
    [] -> Node(..node, handlers: dict.insert(node.handlers, method, handler))
    [first, ..rest] ->
      case first {
        ipath.Literal(s) -> {
          let child = dict.get(node.literals, s) |> unwrap_or_new
          Node(
            ..node,
            literals: dict.insert(node.literals, s, insert(child, method, rest, handler)),
          )
        }
        ipath.Capture(name, ptype) -> {
          let #(child, other) = pop_capture(node.captures, name, ptype)
          let updated = insert(child, method, rest, handler)
          // Keep captures sorted by specificity: IntT before StringT so that
          // a more-constrained segment always takes priority at match time.
          Node(..node, captures: insert_capture(other, name, ptype, updated))
        }
        ipath.Wildcard(name) -> {
          let child = case node.wildcard {
            Some(#(_, n)) -> n
            None -> new()
          }
          Node(..node, wildcard: Some(#(name, insert(child, method, rest, handler))))
        }
      }
  }
}

fn unwrap_or_new(r: Result(Node(handler), Nil)) -> Node(handler) {
  case r {
    Ok(n) -> n
    Error(_) -> new()
  }
}

// Insert a capture entry maintaining specificity order: IntT before StringT.
fn insert_capture(
  captures: List(#(String, ipath.ParamType, Node(handler))),
  name: String,
  ptype: ipath.ParamType,
  child: Node(handler),
) -> List(#(String, ipath.ParamType, Node(handler))) {
  let entry = #(name, ptype, child)
  case ptype {
    ipath.IntT -> [entry, ..captures]
    ipath.StringT -> list.append(captures, [entry])
  }
}

fn pop_capture(
  captures: List(#(String, ipath.ParamType, Node(handler))),
  name: String,
  ptype: ipath.ParamType,
) -> #(Node(handler), List(#(String, ipath.ParamType, Node(handler)))) {
  case captures {
    [] -> #(new(), [])
    [#(n, p, child), ..rest] if n == name && p == ptype -> #(child, rest)
    [other, ..rest] -> {
      let #(found, remaining) = pop_capture(rest, name, ptype)
      #(found, [other, ..remaining])
    }
  }
}

// ---------------------------------------------------------------------------
// Duplicate-check lookup (uses Segment keys, not String keys)
// ---------------------------------------------------------------------------

pub fn get_handler(
  node: Node(handler),
  segments: List(ipath.Segment),
  method: Method,
) -> Result(handler, Nil) {
  case segments {
    [] -> dict.get(node.handlers, method)
    [first, ..rest] ->
      case first {
        ipath.Literal(s) ->
          case dict.get(node.literals, s) {
            Ok(child) -> get_handler(child, rest, method)
            Error(_) -> Error(Nil)
          }
        ipath.Capture(name, ptype) ->
          case find_capture(node.captures, name, ptype) {
            Ok(child) -> get_handler(child, rest, method)
            Error(_) -> Error(Nil)
          }
        ipath.Wildcard(_) ->
          case node.wildcard {
            Some(#(_, child)) -> get_handler(child, rest, method)
            None -> Error(Nil)
          }
      }
  }
}

fn find_capture(
  captures: List(#(String, ipath.ParamType, Node(handler))),
  name: String,
  ptype: ipath.ParamType,
) -> Result(Node(handler), Nil) {
  case captures {
    [] -> Error(Nil)
    [#(n, p, child), ..rest] ->
      case n == name && p == ptype {
        True -> Ok(child)
        False -> find_capture(rest, name, ptype)
      }
  }
}

// ---------------------------------------------------------------------------
// Match (request time)
// ---------------------------------------------------------------------------

pub fn match(
  node: Node(handler),
  method: Method,
  segments: List(String),
) -> Result(#(handler, Dict(String, String)), Nil) {
  do_match(node, method, segments, dict.new())
}

fn do_match(
  node: Node(handler),
  method: Method,
  segments: List(String),
  params: Dict(String, String),
) -> Result(#(handler, Dict(String, String)), Nil) {
  case segments {
    [] ->
      case dict.get(node.handlers, method) {
        Ok(h) -> Ok(#(h, params))
        Error(_) -> try_wildcard(node, method, [], params)
      }
    [seg, ..rest] -> {
      // 1. Literal — O(1)
      let lit = case dict.get(node.literals, seg) {
        Ok(child) -> do_match(child, method, rest, params)
        Error(_) -> Error(Nil)
      }
      case lit {
        Ok(r) -> Ok(r)
        Error(_) -> {
          // 2. Captures — O(captures per level), typically 0 or 1
          let cap = try_captures(node.captures, method, seg, rest, params)
          case cap {
            Ok(r) -> Ok(r)
            Error(_) ->
              // 3. Wildcard — O(1)
              try_wildcard(node, method, segments, params)
          }
        }
      }
    }
  }
}

fn try_captures(
  captures: List(#(String, ipath.ParamType, Node(handler))),
  method: Method,
  seg: String,
  rest: List(String),
  params: Dict(String, String),
) -> Result(#(handler, Dict(String, String)), Nil) {
  case captures {
    [] -> Error(Nil)
    [#(name, ptype, child), ..remaining] -> {
      let valid = case ptype {
        ipath.StringT -> True
        ipath.IntT ->
          case int.parse(seg) {
            Ok(_) -> True
            Error(_) -> False
          }
      }
      case valid {
        True ->
          case do_match(child, method, rest, dict.insert(params, name, seg)) {
            Ok(r) -> Ok(r)
            Error(_) -> try_captures(remaining, method, seg, rest, params)
          }
        False -> try_captures(remaining, method, seg, rest, params)
      }
    }
  }
}

fn try_wildcard(
  node: Node(handler),
  method: Method,
  segments: List(String),
  params: Dict(String, String),
) -> Result(#(handler, Dict(String, String)), Nil) {
  case node.wildcard {
    None -> Error(Nil)
    Some(#(name, child)) ->
      case dict.get(child.handlers, method) {
        Ok(h) -> Ok(#(h, dict.insert(params, name, string.join(segments, "/"))))
        Error(_) -> Error(Nil)
      }
  }
}

// ---------------------------------------------------------------------------
// Allowed methods (for 405 responses)
// ---------------------------------------------------------------------------

pub fn allowed_methods(
  node: Node(handler),
  segments: List(String),
) -> List(Method) {
  do_allowed(node, segments)
  |> list.unique
}

fn do_allowed(node: Node(handler), segments: List(String)) -> List(Method) {
  case segments {
    [] ->
      list.append(dict.keys(node.handlers), wildcard_methods(node.wildcard))
    [seg, ..rest] -> {
      let lit = case dict.get(node.literals, seg) {
        Ok(child) -> do_allowed(child, rest)
        Error(_) -> []
      }
      let cap = captures_allowed(node.captures, seg, rest)
      let wc = wildcard_methods(node.wildcard)
      list.append(lit, list.append(cap, wc))
    }
  }
}

fn captures_allowed(
  captures: List(#(String, ipath.ParamType, Node(handler))),
  seg: String,
  rest: List(String),
) -> List(Method) {
  list.flat_map(captures, fn(c) {
    let #(_, ptype, child) = c
    let valid = case ptype {
      ipath.StringT -> True
      ipath.IntT ->
        case int.parse(seg) {
          Ok(_) -> True
          Error(_) -> False
        }
    }
    case valid {
      True -> do_allowed(child, rest)
      False -> []
    }
  })
}

fn wildcard_methods(wildcard: Option(#(String, Node(handler)))) -> List(Method) {
  case wildcard {
    None -> []
    Some(#(_, child)) -> dict.keys(child.handlers)
  }
}

// ---------------------------------------------------------------------------
// Route introspection
// ---------------------------------------------------------------------------

pub fn to_routes(
  node: Node(handler),
) -> List(#(Method, List(ipath.Segment), handler)) {
  do_to_routes(node, [])
}

fn do_to_routes(
  node: Node(handler),
  acc: List(ipath.Segment),
) -> List(#(Method, List(ipath.Segment), handler)) {
  let current =
    list.map(dict.to_list(node.handlers), fn(h) {
      #(h.0, list.reverse(acc), h.1)
    })

  let lit =
    list.flat_map(dict.to_list(node.literals), fn(e) {
      do_to_routes(e.1, [ipath.Literal(e.0), ..acc])
    })

  let cap =
    list.flat_map(node.captures, fn(c) {
      do_to_routes(c.2, [ipath.Capture(c.0, c.1), ..acc])
    })

  let wc = case node.wildcard {
    None -> []
    Some(#(name, child)) -> do_to_routes(child, [ipath.Wildcard(name), ..acc])
  }

  list.append(current, list.append(lit, list.append(cap, wc)))
}
