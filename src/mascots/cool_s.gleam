import gleam/int
import gleam/list
import gleam/result
import gleam/string
import lustre/attribute
import lustre/element.{type Element}
import lustre/element/html
import lustre/element/svg
import lustre/event

/// The classic "Cool S" doodle, built from the 14 line segments described
/// on its Wikipedia page: three evenly-spaced verticals stacked above
/// another three, two diagonals threading them together, a pointed "V" top
/// and bottom, and two short connectors linking the diagonals to the V's.
pub type Model {
  Model(
    // half the distance between the left/right columns and the centre one
    width: Int,
    // vertical gap between each of the four body rows
    height: Int,
    // how far the top and bottom tips poke out beyond the body rows
    pointiness: Int,
  )
}

pub type Message {
  UserMovedWidth(Int)
  UserMovedHeight(Int)
  UserMovedPointiness(Int)
}

/// The id used for this mascot's root SVG element, shared with anything
/// that needs to refer to it - e.g. the tab that selects it.
pub const id = "cool_s"

fn defaults() -> Model {
  Model(width: 28, height: 16, pointiness: 18)
}

/// Builds the initial model for this mascot, restoring settings from the
/// given query pairs when present (see `to_pairs`).
pub fn init(pairs: List(#(String, String))) -> Model {
  let fallback = defaults()
  let get_int = fn(key: String, min: Int, max: Int, default: Int) -> Int {
    pairs
    |> list.key_find(key)
    |> result.try(int.parse)
    |> result.map(int.clamp(_, min: min, max: max))
    |> result.unwrap(default)
  }

  Model(
    width: get_int("width", 14, 46, fallback.width),
    height: get_int("height", 8, 28, fallback.height),
    pointiness: get_int("pointiness", 0, 40, fallback.pointiness),
  )
}

pub fn update(model: Model, message: Message) -> Model {
  case message {
    UserMovedWidth(width) -> Model(..model, width:)
    UserMovedHeight(height) -> Model(..model, height:)
    UserMovedPointiness(pointiness) -> Model(..model, pointiness:)
  }
}

/// Serialises the model to query pairs, so its settings can be shared via a
/// link (see `init`).
pub fn to_pairs(model: Model) -> List(#(String, String)) {
  [
    #("width", int.to_string(model.width)),
    #("height", int.to_string(model.height)),
    #("pointiness", int.to_string(model.pointiness)),
  ]
}

/// Renders the default Cool S as an SVG string, for offline preview/tooling
/// use (see render_preview.gleam).
pub fn preview() -> String {
  element.to_string(cool_s(defaults()))
}

pub fn view(model: Model) -> Element(Message) {
  element.fragment([
    cool_s(model),
    control("Width", model.width, 14, 46, UserMovedWidth),
    control("Height", model.height, 8, 28, UserMovedHeight),
    control("Pointiness", model.pointiness, 0, 40, UserMovedPointiness),
  ])
}

const border = "#1e1e1e"

const fill = "#ff5252"

/// Renders the whole Cool S mascot as an SVG, purely as a function of the
/// model.
fn cool_s(model: Model) -> Element(Message) {
  let left = -model.width
  let right = model.width
  // the four body rows, evenly spaced above and below the centre line
  let row_top = -{ model.height * 3 / 2 }
  let row_upper = -{ model.height / 2 }
  let row_lower = model.height / 2
  let row_bottom = model.height * 3 / 2
  // the two tips, pushed out past the body rows by however pointy the
  // model is - independent of the body's own row spacing
  let row_tip_top = row_top - model.pointiness
  let row_tip_bottom = row_bottom + model.pointiness
  let half = model.width / 2

  let d =
    [
      line(left, row_top, left, row_upper),
      line(0, row_top, 0, row_upper),
      line(right, row_top, right, row_upper),
      line(left, row_lower, left, row_bottom),
      line(0, row_lower, 0, row_bottom),
      line(right, row_lower, right, row_bottom),
      line(left, row_upper, 0, row_lower),
      line(0, row_upper, right, row_lower),
      corner(left, row_top, 0, row_tip_top, right, row_top),
      corner(left, row_bottom, 0, row_tip_bottom, right, row_bottom),
      line(left, row_lower, -half, 0),
      line(right, row_upper, half, 0),
    ]
    |> string.join(" ")

  html.svg(
    [
      attribute.id(id),
      attribute.attribute("viewBox", "-64 -80 128 160"),
      attribute.attribute("stroke-width", "8"),
      attribute.attribute("stroke-linecap", "round"),
      attribute.attribute("stroke-linejoin", "round"),
      attribute.attribute("stroke", border),
      attribute.attribute("fill", "none"),
    ],
    [
      svg.path([
        attribute.attribute("stroke", fill),
        attribute.attribute("stroke-width", int.to_string(4)),
        attribute.attribute("d", d),
      ]),
      svg.path([attribute.attribute("d", d)]),
    ],
  )
}

fn point(x: Int, y: Int) -> String {
  int.to_string(x) <> "," <> int.to_string(y)
}

fn line(x1: Int, y1: Int, x2: Int, y2: Int) -> String {
  "M" <> point(x1, y1) <> " L" <> point(x2, y2)
}

fn corner(x1: Int, y1: Int, x2: Int, y2: Int, x3: Int, y3: Int) -> String {
  "M" <> point(x1, y1) <> " L" <> point(x2, y2) <> " L" <> point(x3, y3)
}

fn control(
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
