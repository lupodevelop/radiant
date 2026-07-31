//// Typed context-key helpers.

import radiant/request

pub type Key(a) =
  request.Key(a)

pub type Req =
  request.Req

pub type RadiantError =
  request.RadiantError

pub fn key(name: String) -> Key(a) {
  request.key(name)
}

pub fn key_named(namespace: String, name: String) -> Key(a) {
  request.key_named(namespace, name)
}

pub fn set_context(req: Req, k: Key(a), value: a) -> Req {
  request.set_context(req, k, value)
}

pub fn get_context(req: Req, k: Key(a)) -> Result(a, RadiantError) {
  request.get_context(req, k)
}
