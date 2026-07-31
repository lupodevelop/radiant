import gleam/bytes_tree
import gleam/erlang/process
import gleam/http/response
import mist
import radiant

pub fn serve(router: radiant.Router, port: Int) {
  let assert Ok(_) =
    mist.new(fn(req) {
      let resp = radiant.handle(router, req)
      response.set_body(resp, mist.Bytes(bytes_tree.from_bit_array(resp.body)))
    })
    |> mist.read_request_body(
      bytes_limit: 4_194_304,
      failure_response: response.new(413)
        |> response.set_body(
          mist.Bytes(bytes_tree.from_bit_array(<<"Request too large":utf8>>)),
        ),
    )
    |> mist.port(port)
    |> mist.start()

  process.sleep_forever()
}
