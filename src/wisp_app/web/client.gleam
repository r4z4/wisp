import gleam/dict
import gleam/dynamic.{type Dynamic}
import gleam/http.{Get, Post}
import gleam/int
import gleam/json
import gleam/list
import gleam/option.{None, Some}
import gleam/pgo.{Returned}
import gleam/result.{try}
import wisp.{type Request, type Response}
import wisp_app/web.{type Context}

// This request handler is used for requests to `/clients`.
//
pub fn all(req: Request, ctx: Context) -> Response {
  // Dispatch to the appropriate handler based on the HTTP method.
  case req.method {
    Get -> list_clients(ctx)
    Post -> create_client(req, ctx)
    _ -> wisp.method_not_allowed([Get, Post])
  }
}

// This request handler is used for requests to `/clients/:id`.
//
pub fn one(req: Request, ctx: Context, id: String) -> Response {
  // Dispatch to the appropriate handler based on the HTTP method.
  case req.method {
    Get -> read_client(ctx, id)
    _ -> wisp.method_not_allowed([Get])
  }
}

pub type Client {
  Client(client_f_name: String, territory_id: Int)
}

// This handler returns a list of all the clients in the database, in JSON
// format.
//
pub fn list_clients(ctx: Context) -> Response {
  // An SQL statement to run. It takes one int as a parameter
  let sql =
    "
  select
    id
  from
    client"

  // This is the decoder for the value returned by the query
  // let return_type = dynamic.list(dynamic.int)
  let result = {
    // Get all the ids from the database.
    use ids <- try(pgo.execute(sql, ctx.db, [], dynamic.list(dynamic.int)))

    // Convert the ids into a JSON array of objects.
    Ok(
      json.to_string_builder(
        json.object([
          #(
            "client",
            json.array(ids, fn(id) { json.object([#("id", json.string(id))]) }),
          ),
        ]),
      ),
    )
  }

  case result {
    // When everything goes well we return a 200 response with the JSON.
    Ok(json) -> wisp.json_response(json, 200)

    // In a later example we will see how to return specific errors to the user
    // depending on what went wrong. For now we will just return a 500 error.
    Error(Nil) -> wisp.internal_server_error()
  }
}

pub fn create_client(req: Request, ctx: Context) -> Response {
  // Read the JSON from the request body.
  use json <- wisp.require_json(req)

  let result = {
    // Decode the JSON into a client record.
    use client <- try(decode_client(json))

    // Save the client to the database.
    use id <- try(save_to_database(ctx.db, client))

    // Construct a JSON payload with the id of the newly created client.
    Ok(json.to_string_builder(json.object([#("id", json.string(id))])))
  }

  // Return an appropriate response depending on whether everything went well or
  // if there was an error.
  case result {
    Ok(json) -> wisp.json_response(json, 201)
    Error(Nil) -> wisp.unprocessable_entity()
  }
}

pub fn read_client(ctx: Context, id: String) -> Response {
  let result = {
    // Read the client with the given id from the database.
    use client <- try(read_from_database(ctx.db, id))

    // Construct a JSON payload with the client's details.
    Ok(
      json.to_string_builder(
        json.object([
          #("id", json.string(id)),
          #("client_f_name", json.string(client.client_f_name)),
          #("territory_id", json.int(client.territory_id)),
        ]),
      ),
    )
  }

  // Return an appropriate response.
  case result {
    Ok(json) -> wisp.json_response(json, 200)
    Error(Nil) -> wisp.not_found()
  }
}

fn decode_client(json: Dynamic) -> Result(Client, Nil) {
  let decoder =
    dynamic.decode2(
      Client,
      dynamic.field("client_f_name", dynamic.string),
      dynamic.field("territory_id", dynamic.int),
    )
  let result = decoder(json)

  // In this example we are not going to be reporting specific errors to the
  // user, so we can discard the error and replace it with Nil.
  result
  |> result.nil_error
}

/// Save a client to the database and return the id of the newly created record.
pub fn save_to_database(
  db: pgo.Connection,
  client: Client,
) -> Result(String, Nil) {
  // In a real application you might use a database client with some SQL here.
  // Instead we create a simple dict and save that.
  //   let data =
  //     dict.from_list([
  //       #("client_f_name", client.client_f_name),
  //       #("territory_id", int.to_string(client.territory_id)),
  //     ])
  //   tiny_database.insert(db, data)

  let sql =
    "
    INSERT INTO clients (client_f_name, territory_id)
    VALUES($1, $2)"

  let res =
    pgo.execute(
      sql,
      db,
      [pgo.text(client.client_f_name), pgo.int(client.territory_id)],
      // If not interested in return values
      dynamic.dynamic,
    )

  let string = all(res)
}

pub fn read_from_database(db: pgo.Connection, id: String) -> Result(Client, Nil) {
  // In a real application you might use a database client with some SQL here.
  let sql =
    "
    select
        client_f_name, territory_id
    from
        client
    WHERE client_id = $1"

  let return_type = dynamic.tuple2(dynamic.string, dynamic.int)

  // This is the decoder for the value returned by the query
  // let return_type = dynamic.list(dynamic.int)
  use data <- pgo.execute(sql, db, [all(int.parse(id))], return_type)

  // use data <- try(tiny_database.read(db, id))
  use client_f_name <- try(dict.get(data, "client_f_name"))
  use territory_id <- try(dict.get(data, "territory_id"))
  Ok(Client(client_f_name, territory_id))
}
