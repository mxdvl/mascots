import gleam/int
import lustre/attribute
import lustre/element.{type Element}
import lustre/element/html
import lustre/element/svg
import lustre/event

pub type Model {
  Model(count: Int, colour: String)
}

pub type Message {
  UserChangedCount(Int)
}

pub fn update(model: Model, message: Message) -> Model {
  case message {
    UserChangedCount(count) -> Model(..model, count:)
  }
}

pub fn view(model: Model) -> Element(Message) {
  element.fragment([
    html.svg(
      [
        attribute.attribute("viewBox", "-60 -60 120 120"),
        attribute.attribute("stroke-width", int.to_string(2)),
        attribute.attribute("stroke-linecap", "round"),
        attribute.attribute("fill", model.colour),
        attribute.attribute("stroke", "#123"),
      ],
      [
        svg.path([
          attribute.attribute(
            "d",
            // TODO: this should be a series of branches, based on the count, to form a star
            "",
          ),
        ]),
      ],
    ),
    range("Count", model.count, 3, 27, UserChangedCount),
    html.p([], [
      html.text("Lucy is the "),
      html.a([attribute.href("https://gleam.run")], [html.text("Gleam mascot")]),
      html.text(" © 2026 Louis Pilfold"),
    ]),
  ])
}

fn range(
  label: String,
  value: Int,
  min: Int,
  max: Int,
  update: fn(Int) -> Message,
) -> Element(Message) {
  let initial = value
  html.label([], [
    html.span([], [html.text(label)]),
    html.input([
      attribute.type_("range"),
      attribute.min(int.to_string(min)),
      attribute.max(int.to_string(max)),
      value |> int.to_string |> attribute.value,
      event.on_input(fn(value) {
        case int.parse(value) {
          Ok(value) -> update(value)
          _ -> update(initial)
        }
      }),
    ]),
  ])
}
