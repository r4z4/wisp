import gleam/dynamic
import gleam/erlang/process
import gleam/io
import gleam/option.{None, Some}
import gleam/pgo
import gleeunit/should
import mist
import wisp
import wisp_app/router
import wisp_app/web

pub fn main() {
  // This sets the logger to print INFO level logs, and other sensible defaults
  // for a web application.
  wisp.configure_logger()

  // Here we generate a secret key, but in a real application you would want to
  // load this from somewhere so that it is not regenerated on every restart.
  let secret_key_base = wisp.random_string(64)

  let db =
    pgo.connect(
      pgo.Config(
        ..pgo.default_config(),
        host: "localhost",
        user: "postgres",
        password: Some("postgres"),
        database: "htmx_actix",
        pool_size: 15,
      ),
    )

  let context = web.Context(db: db)

  // An SQL statement to run. It takes one int as a parameter
  let sql =
    "
      select
        client_f_name, client_l_name, territory_id, specialty_id
      from
        clients
      where
        id = $1"

  // This is the decoder for the value returned by the query
  let return_type =
    dynamic.tuple4(
      dynamic.string,
      dynamic.string,
      dynamic.int,
      dynamic.int,
      // dynamic.list(dynamic.string),
    )

  let response = pgo.execute(sql, db, [pgo.int(1)], return_type)

  io.debug(response)

  // Start the Mist web server.
  let assert Ok(_) =
    wisp.mist_handler(router.handle_request, secret_key_base)
    |> mist.new
    |> mist.port(8000)
    |> mist.start_http

  // The web server runs in new Erlang process, so put this one to sleep while
  // it works concurrently.
  process.sleep_forever()
}
