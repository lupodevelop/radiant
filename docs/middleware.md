# Middleware

Middleware wraps every request that passes through the router. Apply with `radiant.middleware/2`.
First added = outermost (executes first on the way in, last on the way out).

```gleam
radiant.new()
|> radiant.middleware(radiant.cors(radiant.default_cors()))
|> radiant.middleware(radiant.log(io.println))
|> radiant.middleware(radiant.rescue(fn(err) {
  io.debug(err)
  radiant.internal_server_error()
}))
|> radiant.get("/", handler)
```

## Built-in middleware

### `cors`

```gleam
// Default: any origin, GET/POST/PUT/PATCH/DELETE, content-type + authorization, 24h cache
radiant.middleware(radiant.cors(radiant.default_cors()))

// Custom config
radiant.middleware(radiant.cors(radiant.CorsConfig(
  origins: ["https://myapp.com"],
  methods: [http.Get, http.Post],
  headers: ["content-type", "authorization", "x-api-key"],
  max_age: 3600,
)))
```

Handles `OPTIONS` preflight automatically. `Access-Control-Allow-Origin` is only emitted when
an `Origin` header is present in the request.

### `log`

```gleam
// Any fn(String) -> a works
radiant.middleware(radiant.log(io.println))

// With woof
radiant.middleware(radiant.log(fn(msg) { woof.log(logger, woof.Info, msg, []) }))
```

Logs `METHOD /path` before the handler and `METHOD /path → STATUS` after.

### `rescue`

```gleam
radiant.middleware(radiant.rescue(fn(err) {
  io.debug(err)
  radiant.internal_server_error()
}))
```

Catches Erlang exceptions (panics, crashes) in handlers and returns a response instead of crashing
the process. Essential for production BEAM deployments.

### `json_body`

Parse the request body as JSON and store the result in context. Returns 400 if the body is not
valid JSON or doesn't match the decoder. Skips parsing when the body is empty (GET, HEAD, DELETE).

```gleam
pub const payload_key: radiant.Key(CreateUser) = radiant.key("routes:create_user")

let decoder = {
  use name  <- decode.field("name", decode.string)
  use email <- decode.field("email", decode.string)
  decode.success(CreateUser(name:, email:))
}

radiant.new()
|> radiant.middleware(radiant.json_body(payload_key, decoder))
|> radiant.post("/users", fn(req) {
  let assert Ok(payload) = radiant.get_context(req, payload_key)
  // payload: CreateUser — no Dynamic, no decoding in the handler
  ...
})
```

### `serve_static`

```gleam
let fs = radiant.FileSystem(
  read_bits: simplifile.read_bits,
  is_file: simplifile.is_file,
)

radiant.middleware(radiant.serve_static(prefix: "/assets", from: "priv/static", via: fs))
```

Strips the prefix, resolves the file path inside the directory, and serves it with MIME detection.
Falls through to the next handler if the file doesn't exist. The `FileSystem` interface is swappable —
use any IO library or an in-memory implementation for tests.

## Custom middleware

A middleware is `fn(fn(Req) -> Response) -> fn(Req) -> Response`.

```gleam
fn timing_middleware(next: fn(radiant.Req) -> Response(BitArray)) -> fn(radiant.Req) -> Response(BitArray) {
  fn(req) {
    let start = erlang.system_time(erlang.Millisecond)
    let resp  = next(req)
    let elapsed = erlang.system_time(erlang.Millisecond) - start
    resp |> radiant.with_header("x-response-time", int.to_string(elapsed) <> "ms")
  }
}

router |> radiant.middleware(timing_middleware)
```

## Context key namespacing

`radiant.key("user")` is backed by the string `"user"`. If two middlewares call `key("user")`
but expect different types, they silently overwrite each other in the context dict.

**Always use fully-qualified key names:**

```gleam
// Bad — collides with any other "user" key
pub const user_key = radiant.key("user")

// Good — module-qualified, collision-safe
pub const user_key     = radiant.key("auth_middleware:user")
pub const session_key  = radiant.key("session_middleware:session")
pub const payload_key  = radiant.key("routes:create_user")
```

This is especially important when mixing third-party middleware libraries. Gleam has no macros,
so there is no compile-time enforcement — the prefix convention is the correct mitigation.

## Route-level middleware (pattern)

Radiant applies middleware globally. For route-level control, use function composition:

```gleam
fn require_auth(handler: fn(radiant.Req, User) -> Response(BitArray)) {
  fn(req: radiant.Req) -> Response(BitArray) {
    case radiant.get_context(req, user_key) {
      Ok(user) -> handler(req, user)
      Error(_) -> radiant.unauthorized()
    }
  }
}

router
|> radiant.middleware(auth_middleware)  // stores user in context
|> radiant.get1("/profile/<id:int>", user_id, require_auth(profile_handler))
```
