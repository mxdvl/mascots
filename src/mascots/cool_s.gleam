import gleam/float
import gleam/int
import gleam/list
import gleam/result
import gleam/string
import lustre/attribute
import lustre/element.{type Element}
import lustre/element/html
import lustre/element/svg
import lustre/event

/// The classic "Cool S" doodle, drawn as a single continuous centreline
/// (see `at`/`waypoints`) rather than as a filled outline - a top tip, an
/// outer shoulder, a hooked waist, and the shape's centre, mirrored through
/// that centre for the interlocking, infinity-symbol look.
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
    control("Width", model.width, 14, 46, 2, UserMovedWidth),
    control("Height", model.height, 8, 28, 1, UserMovedHeight),
    control("Pointiness", model.pointiness, 0, 40, 1, UserMovedPointiness),
  ])
}

const border = "#1e1e1e"

/// Renders the whole Cool S mascot as an SVG, purely as a function of the
/// model. For now this just draws the single continuous centreline (see
/// `at`) - no outline, no rainbow yet.
fn cool_s(model: Model) -> Element(Message) {
  html.svg(
    [
      attribute.id(id),
      attribute.attribute("viewBox", "-64 -80 128 160"),
      attribute.attribute("stroke-width", "4"),
      attribute.attribute("stroke-linecap", "round"),
      attribute.attribute("stroke-linejoin", "round"),
      attribute.attribute("stroke", border),
      attribute.attribute("fill", "none"),
    ],
    [svg.path([attribute.attribute("d", path(model))])],
  )
}

/// The waypoints of the Cool S's single continuous centreline: a plain
/// zigzag from the top tip to the bottom tip - top-left diagonal, straight
/// down the left side, a diagonal across to the right, straight down the
/// right side, then a bottom-right diagonal in to the bottom tip.
///
/// Built from just the first half (top tip down to the left side's lower
/// point), which is then mirrored through the centre (rotating each point
/// 180°) to produce the other half. Because both halves are true rotations
/// of one another, the line's exact midpoint (by arc length) always lands
/// precisely on the centre of the shape, at `(0, 0)`.
fn waypoints(model: Model) -> List(#(Float, Float)) {
  let w = int.to_float(model.width)
  let h = int.to_float(model.height)
  let p = int.to_float(model.pointiness)

  // how far down the left/right sides the shoulder and inner points sit,
  // as a fraction of the half-height
  let shoulder = h *. 0.55
  let inner = h *. 0.15

  let first_half = [
    // middle top
    #(0.0, 0.0 -. h -. p),
    // top-left diagonal, down to the left shoulder
    #(0.0 -. w, 0.0 -. shoulder),
    // straight down the left side
    #(0.0 -. w, 0.0 -. inner),
  ]

  let second_half =
    first_half
    |> list.reverse
    |> list.map(fn(point) {
      let #(x, y) = point
      #(0.0 -. x, 0.0 -. y)
    })

  list.append(first_half, second_half)
}

/// The position along the Cool S's centreline at `t`, where `t` is a
/// fraction of the total line length: `0.0` is the top tip, `1.0` is the
/// bottom tip, and (thanks to the symmetry in `waypoints`) `0.5` always
/// lands exactly in the middle of the shape, at `(0, 0)`.
pub fn at(model: Model, t: Float) -> #(Float, Float) {
  let points = waypoints(model)
  let segments = list.zip(points, list.drop(points, 1))
  let lengths = list.map(segments, segment_length)
  let target = t *. float.sum(lengths)
  walk(segments, lengths, target)
}

fn segment_length(segment: #(#(Float, Float), #(Float, Float))) -> Float {
  let #(#(x1, y1), #(x2, y2)) = segment
  let assert Ok(length) =
    float.square_root(
      { x2 -. x1 } *. { x2 -. x1 } +. { y2 -. y1 } *. { y2 -. y1 },
    )
  length
}

fn walk(
  segments: List(#(#(Float, Float), #(Float, Float))),
  lengths: List(Float),
  target: Float,
) -> #(Float, Float) {
  case segments, lengths {
    [#(#(x1, y1), #(x2, y2)), ..rest_segments], [length, ..rest_lengths] ->
      case target <=. length || rest_segments == [] {
        True -> {
          let fraction = case length >. 0.0 {
            True -> float.clamp(target /. length, min: 0.0, max: 1.0)
            False -> 0.0
          }
          #(x1 +. { x2 -. x1 } *. fraction, y1 +. { y2 -. y1 } *. fraction)
        }
        False -> walk(rest_segments, rest_lengths, target -. length)
      }
    _, _ -> #(0.0, 0.0)
  }
}

/// Renders the centreline as an SVG path `d` string.
fn path(model: Model) -> String {
  case waypoints(model) {
    [] -> ""
    [first, ..rest] ->
      "M"
      <> format_point(first)
      <> " L"
      <> { rest |> list.map(format_point) |> string.join(" ") }
  }
}

fn format_point(point: #(Float, Float)) -> String {
  let #(x, y) = point
  round(x) <> "," <> round(y)
}

fn round(value: Float) -> String {
  value |> float.to_precision(3) |> float.to_string
}

fn control(
  label: String,
  value: Int,
  min: Int,
  max: Int,
  step: Int,
  update: fn(Int) -> Message,
) -> Element(Message) {
  let initial = value
  html.label([], [
    html.span([], [html.text(label)]),
    html.input([
      attribute.type_("range"),
      attribute.step(int.to_string(step)),
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
