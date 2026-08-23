import lustre/attribute
import gleam/int
import lustre
import lustre/element.{type Element}
import lustre/element/html
import lustre/event

pub fn main() {
  let app = lustre.simple(init, update, view)
  let assert Ok(_) = lustre.start(app, "#app", Nil)

  Nil
}

type Model =
  Int

fn init(_) -> Model {
  0
}

type Message {
  UserClickedIncrement
  UserClickedDecrement
  UserMovedRange(value: Model)
}

fn update(model: Model, message: Message) -> Model {
  case message {
    UserClickedIncrement -> model + 1
    UserClickedDecrement -> model - 1
    UserMovedRange(value) -> value
  }
}

fn view(model: Model) -> Element(Message) {
  let count = int.to_string(model)

  html.div([], [
    html.button([event.on_click(UserClickedIncrement)], [
      html.text("+")
    ]),
    html.text(count),
    html.button([event.on_click(UserClickedDecrement)], [
      html.text("-")
    ]),
    range(model, UserMovedRange),
    range(model, UserMovedRange),
  ])
}

fn range(value: Int, update: fn(Model) -> Message) -> Element(Message) {
  let initial = value
  html.input([
    attribute.type_("range"),
    value |> int.to_string |> attribute.value,
    event.on_input(fn(value) {
      case int.parse(value) {
        Ok(value) -> update(value)
        _ -> update(initial)
      }
    }),
  ])
}
