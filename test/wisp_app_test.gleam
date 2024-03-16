import gleam/json
import gleam/option.{None, Some}
import gleam/pgo
import gleeunit
import gleeunit/should
import wisp/testing
import wisp_app
import wisp_app/router
import wisp_app/web.{type Context, Context}
import wisp_app/web/client.{Client}

pub fn main() {
  gleeunit.main()
}

fn with_context(testcase: fn(Context) -> t) -> t {
  // Create a new database connection for this test
  // use db <- tiny_database.with_connection(app.data_directory)
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

  // Truncate the database so there is no prexisting data from previous tests
  // let assert Ok(_) = tiny_database.truncate(db)
  let context = Context(db: db)

  // Run the test with the context
  testcase(context)
}

pub fn get_unknown_test() {
  use ctx <- with_context
  let request = testing.get("/", [])
  let response = router.handle_request(request, ctx)

  response.status
  |> should.equal(404)
}

pub fn list_people_test() {
  use ctx <- with_context

  let response = router.handle_request(testing.get("/clients", []), ctx)
  response.status
  |> should.equal(200)
  response.headers
  |> should.equal([#("content-type", "application/json")])

  // Initially there are no clients in the database
  response
  |> testing.string_body
  |> should.equal("{\"clients\":[]}")

  // Create a new client
  let assert Ok(id) = client.save_to_database(ctx.db, Client("Jane", 1))

  // The id of the new client is listed by the API
  let response = router.handle_request(testing.get("/clients", []), ctx)
  response
  |> testing.string_body
  |> should.equal("{\"clients\":[{\"id\":\"" <> id <> "\"}]}")
}

// pub fn create_person_test() {
//   use ctx <- with_context
//   let json =
//     json.object([
//       #("name", json.string("Lucy")),
//       #("favourite-colour", json.string("Pink")),
//     ])
//   let request = testing.post_json("/clients", [], json)
//   let response = router.handle_request(request, ctx)

//   response.status
//   |> should.equal(201)

//   // The request created a new client in the database
//   let assert Ok([id]) = tiny_database.list(ctx.db)

//   response
//   |> testing.string_body
//   |> should.equal("{\"id\":\"" <> id <> "\"}")
// }

// pub fn create_person_missing_parameters_test() {
//   use ctx <- with_context
//   let json = json.object([#("name", json.string("Lucy"))])
//   let request = testing.post_json("/clients", [], json)
//   let response = router.handle_request(request, ctx)

//   response.status
//   |> should.equal(422)

//   // Nothing was created in the database
//   let assert Ok([]) = tiny_database.list(ctx.db)
// }

pub fn read_person_test() {
  use ctx <- with_context
  let assert Ok(id) = client.save_to_database(ctx.db, Client("Jane", 1))
  let request = testing.get("/clients/" <> id, [])
  let response = router.handle_request(request, ctx)

  response.status
  |> should.equal(200)

  response
  |> testing.string_body
  |> should.equal(
    "{\"id\":\"" <> id <> "\",\"name\":\"Jane\",\"favourite-colour\":\"Red\"}",
  )
}
