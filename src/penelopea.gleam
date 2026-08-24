import gleam/int
import lustre
import lustre/attribute
import lustre/element.{type Element}
import lustre/element/html
import lustre/element/svg
import lustre/event

pub fn main() {
  let app = lustre.simple(init, update, view)
  let assert Ok(_) = lustre.start(app, "#app", Nil)

  Nil
}

type Model =
  Int

fn init(_) -> Model {
  18
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
  let frame = int.to_string(model)
  let offset = 4

  element.fragment([
    html.svg(
      [
        attribute.attribute("viewBox", "-60 -60 120 120"),
        attribute.attribute("stroke-width", int.to_string(2)),
        attribute.attribute("stroke-linecap", "round"),
        attribute.attribute("stroke", "var(--border)"),
      ],
      [
        svg.circle([
          attribute.attribute("fill", "green"),
          attribute.attribute("r", int.to_string(48)),
        ]),
        svg.g(
          [
            attribute.attribute("data-name", "glasses"),
            attribute.attribute("fill", "none"),
          ],
          [
            svg.circle([
              attribute.attribute("r", frame),
              attribute.attribute("cx", int.to_string(-model - offset)),
              attribute.attribute("cy", int.to_string(-2)),
            ]),
            svg.circle([
              attribute.attribute("stroke", "none"),
              attribute.attribute("fill", "var(--border)"),
              attribute.attribute("r", int.to_string(1)),
              attribute.attribute("cx", int.to_string(-8)),
            ]),
            svg.path([
              attribute.attribute("d", "M-5,-4 a 8,8 0 0 1 10,0"),
            ]),
            svg.circle([
              attribute.attribute("stroke", "none"),
              attribute.attribute("fill", "var(--border)"),
              attribute.attribute("r", int.to_string(1)),
              attribute.attribute("cx", int.to_string(8)),
            ]),
            svg.circle([
              attribute.attribute("r", frame),
              attribute.attribute("cx", int.to_string(model + offset)),
              attribute.attribute("cy", int.to_string(-2)),
            ]),
            // mouth
            svg.path([
              attribute.attribute("d", "M-2,3 a 2.2,2.2 0 0 0 4,0"),
            ]),
          ],
        ),
      ],
    ),
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
