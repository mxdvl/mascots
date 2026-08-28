import gleam/float
import gleam/int
import gleam/list
import gleam/string
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
      [svg.path([attribute.attribute("d", star_path(model.count))])],
    ),
    range("Count", model.count, 3, 27, UserChangedCount),
    html.p([], [
      html.text("Lucy is the "),
      html.a([attribute.href("https://gleam.run")], [html.text("Gleam mascot")]),
      html.text(" © 2026 Louis Pilfold"),
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

// --- star geometry ---------------------------------------------------------
//
// A point in the Cartesian plane: the only coordinate system SVG path
// commands understand.
type CartesianPoint {
  CartesianPoint(x: Float, y: Float)
}

// A point in polar coordinates: a distance from the origin (`radius`) and an
// angle from it, in radians (`theta`), measured clockwise from straight up.
// Rotating a shape around the origin is then just adding to `theta`.
type PolarPoint {
  PolarPoint(radius: Float, theta: Float)
}

fn to_polar(point: CartesianPoint) -> PolarPoint {
  let assert Ok(radius) =
    float.square_root(point.x *. point.x +. point.y *. point.y)
  PolarPoint(radius:, theta: atan2(point.x, 0.0 -. point.y))
}

fn to_cartesian(point: PolarPoint) -> CartesianPoint {
  CartesianPoint(
    x: point.radius *. sin(point.theta),
    y: 0.0 -. point.radius *. cos(point.theta),
  )
}

/// Rotates a point around the origin by `theta` radians.
fn rotate(point: PolarPoint, by theta: Float) -> PolarPoint {
  PolarPoint(..point, theta: point.theta +. theta)
}

/// Mirrors a Cartesian point across the vertical axis.
fn flip(point: CartesianPoint) -> CartesianPoint {
  CartesianPoint(..point, x: 0.0 -. point.x)
}

/// Builds the outline of a `count`-pointed star as an SVG path `d` string.
///
/// A single spike is drawn by hand as two Cartesian points: its tip, sitting
/// straight up from the centre, and the corner where it meets its clockwise
/// neighbour. The corner where it meets its anticlockwise neighbour is just
/// that same corner, flipped across the vertical axis.
///
/// Converting both points to polar coordinates lets that one spike be
/// stamped out `count` times around the origin, simply by rotating. Because
/// each spike's corners sit exactly `half_angle` either side of its tip,
/// rotating by a full `step` always lands one spike's clockwise corner
/// exactly on the next spike's anticlockwise corner - so the outline never
/// has to jump, and only one of the two corners needs to be kept per spike.
fn star_path(count: Int) -> String {
  let outer_radius = 50.0
  let inner_radius = 20.0
  let step = 2.0 *. pi /. int.to_float(count)
  let half_angle = step /. 2.0

  let tip = to_polar(CartesianPoint(x: 0.0, y: 0.0 -. outer_radius))
  let corner =
    CartesianPoint(
      x: inner_radius *. sin(half_angle),
      y: 0.0 -. inner_radius *. cos(half_angle),
    )
    |> flip
    |> to_polar

  let points =
    list.repeat(Nil, count)
    |> list.index_map(fn(_, index) {
      let angle = int.to_float(index) *. step
      [rotate(corner, by: angle), rotate(tip, by: angle)]
    })
    |> list.flatten
    |> list.map(to_cartesian)

  case points {
    [] -> ""
    [first, ..rest] ->
      [
        "M" <> point_to_string(first),
        ..list.map(rest, fn(point) { "L" <> point_to_string(point) })
      ]
      |> string.join(" ")
      <> " Z"
  }
}

fn point_to_string(point: CartesianPoint) -> String {
  round(point.x) <> "," <> round(point.y)
}

fn round(value: Float) -> String {
  value |> float.to_precision(2) |> float.to_string
}

const pi = 3.141592653589793

@external(javascript, "../mascots_ffi.mjs", "sin")
fn sin(theta: Float) -> Float

@external(javascript, "../mascots_ffi.mjs", "cos")
fn cos(theta: Float) -> Float

@external(javascript, "../mascots_ffi.mjs", "atan2")
fn atan2(y: Float, x: Float) -> Float
