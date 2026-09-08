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

/// Colours run from the outermost ribbon to the centre fill.
pub type Model {
  Model(count: Int, colours: List(String))
}

pub type Message {
  UserChangedCount(Int)
}

/// The id used for this mascot's root SVG element, shared with anything
/// that needs to refer to it - e.g. the tab that selects it.
pub const id = "lucy"

const ribbon_clip_id = "lucy_ribbons"

const max_colours = 6

const default_colour = "ffaff3"

const ribbon_depth = 8.0

const border_width = 3.0

fn defaults() -> Model {
  Model(count: 7, colours: [default_colour])
}

/// Builds the initial model, restoring settings from the given query pairs
/// when present (see `to_pairs`).
pub fn init(pairs: List(#(String, String))) -> Model {
  let fallback = defaults()

  let count =
    pairs
    |> list.key_find("count")
    |> result.try(int.parse)
    |> result.map(int.clamp(_, min: 3, max: 27))
    |> result.unwrap(fallback.count)

  let colours =
    pairs
    |> list.key_filter("colour")
    |> list.flat_map(string.split(_, ","))
    |> list.filter(fn(colour) { colour != "" })
    |> list.take(max_colours)
    |> list.map(normalise_colour)
  let colours = case colours {
    [] -> fallback.colours
    colours -> colours
  }

  Model(count:, colours:)
}

fn normalise_colour(colour: String) -> String {
  let colour = colour |> string.remove_prefix("#") |> string.lowercase
  let valid =
    string.length(colour) == 6
    && list.all(string.to_graphemes(colour), fn(digit) {
      string.contains("0123456789abcdef", digit)
    })
  case valid {
    True -> colour
    False -> default_colour
  }
}

pub fn update(model: Model, message: Message) -> Model {
  case message {
    UserChangedCount(count) -> Model(..model, count:)
  }
}

/// Serialises the model to query pairs, so its settings can be shared via a
/// link (see `init`).
pub fn to_pairs(model: Model) -> List(#(String, String)) {
  [
    #("count", int.to_string(model.count)),
    ..list.map(model.colours, fn(colour) { #("colour", colour) })
  ]
}

const border = "#1e1e1e"

pub fn view(model: Model) -> Element(Message) {
  element.fragment([
    html.svg(
      [
        attribute.id(id),
        attribute.attribute("viewBox", "-60 -60 120 120"),
        attribute.attribute("stroke-width", float.to_string(border_width)),
        attribute.attribute("stroke-linecap", "round"),
        attribute.attribute("stroke-linejoin", "round"),
        attribute.attribute("stroke", border),
      ],
      [
        svg.g(
          [
            attribute.attribute("transform", "rotate(-13)"),
          ],
          [body(model)],
        ),
      ],
    ),
    range("Count", model.count, 2, 27, UserChangedCount),
    html.p([], [
      html.text("Lucy is the "),
      html.a([attribute.href("https://gleam.run")], [html.text("Gleam mascot")]),
      html.text(" © 2026 Louis Pilfold"),
    ]),
  ])
}

/// Clip broad outline strokes to the inside of the star, then paint them
/// widest first. Unlike scaled stars, these bands keep a consistent width
/// around the rounded tips and valleys, without changing Lucy's silhouette.
fn body(model: Model) -> Element(Message) {
  let outline = star_path(model.count)
  let centre_colour =
    model.colours |> list.last |> result.unwrap(default_colour)
  let band_count = list.length(model.colours) - 1
  // The outline covers half its width inside the star; start the visible
  // stripes after it, rather than letting it hide the outermost colour.
  let visible_depth = ribbon_depth -. border_width /. 2.0
  let ribbons = {
    use colour, index <- list.index_map(list.take(model.colours, band_count))
    let fraction = int.to_float(index + 1) /. int.to_float(band_count)
    let width = border_width +. 2.0 *. visible_depth *. fraction
    svg.path([
      attribute.attribute("d", outline),
      attribute.attribute("fill", "none"),
      attribute.attribute("stroke", "#" <> colour),
      attribute.attribute("stroke-width", float.to_string(width)),
    ])
  }
  element.fragment([
    svg.defs([], [
      svg.clip_path([attribute.id(ribbon_clip_id)], [
        svg.path([attribute.attribute("d", outline)]),
      ]),
    ]),
    svg.path([
      attribute.attribute("d", outline),
      attribute.attribute("fill", "#" <> centre_colour),
      attribute.attribute("stroke", "none"),
    ]),
    svg.g(
      [attribute.attribute("clip-path", "url(#" <> ribbon_clip_id <> ")")],
      list.reverse(ribbons),
    ),
    svg.path([
      attribute.attribute("d", outline),
      attribute.attribute("fill", "none"),
    ]),
    face(face_colour(centre_colour)),
  ])
}

fn face_colour(colour: String) -> String {
  let channel = fn(offset: Int) {
    colour
    |> string.slice(offset, 2)
    |> int.base_parse(16)
    |> result.unwrap(0)
  }
  let brightness = 299 * channel(0) + 587 * channel(2) + 114 * channel(4)
  case brightness < 128_000 {
    True -> "#ffffff"
    False -> border
  }
}

/// A simple, friendly face, sitting in the middle of the star regardless of
/// how many branches it has, since the body's radius never changes.
fn face(colour: String) -> Element(Message) {
  let x = 12
  let y = 3
  let radius = 3
  let mouth = 3
  let offset = 2
  svg.g(
    [attribute.attribute("stroke", "none"), attribute.attribute("fill", colour)],
    [
      // eyes
      svg.circle([
        attribute.attribute("cx", int.to_string(-x)),
        attribute.attribute("cy", int.to_string(-y)),
        attribute.attribute("r", int.to_string(radius)),
      ]),
      svg.circle([
        attribute.attribute("cx", int.to_string(x)),
        attribute.attribute("cy", int.to_string(-y)),
        attribute.attribute("r", int.to_string(radius)),
      ]),
      // mouth
      svg.path([
        attribute.attribute("fill", "none"),
        attribute.attribute("stroke", colour),
        attribute.attribute(
          "d",
          [
            "M" <> int.to_string(-mouth) <> "," <> int.to_string(offset),
            "A"
              <> int.to_string(mouth)
              <> ","
              <> int.to_string(mouth)
              <> " 0 0 0 "
              <> int.to_string(mouth)
              <> ","
              <> int.to_string(offset),
          ]
            |> string.join(" "),
        ),
      ]),
    ],
  )
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

/// How rounded a star's tips are: 0 would be a sharp point, 0.5 would pull
/// the curve all the way back to its neighbours.
const tip_roundness = 0.42

/// How rounded a star's inner corners (the valleys between branches) are.
/// Kept gentler than the tips, so the branches stay readable as branches.
const valley_roundness = 0.16

/// Builds the outline of a `count`-pointed star as an SVG path `d` string.
fn star_path(count: Int) -> String {
  star_vertices(count) |> rounded_path
}

/// Places the vertices of a `count`-pointed star, each tagged with how
/// rounded that particular corner should be.
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
fn star_vertices(count: Int) -> List(#(CartesianPoint, Float)) {
  let outer_radius = 50.0
  let inner_radius = 24.0
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

  list.repeat(Nil, count)
  |> list.index_map(fn(_, index) {
    let angle = int.to_float(index) *. step
    [
      #(rotate(corner, by: angle) |> to_cartesian, valley_roundness),
      #(rotate(tip, by: angle) |> to_cartesian, tip_roundness),
    ]
  })
  |> list.flatten
}

/// Softens every corner of a closed polygon into a rounded curve, rather
/// than meeting it at a sharp point: for each vertex, pull back along both
/// its edges by that vertex's own roundness fraction, then curve through
/// the original vertex with a quadratic Bezier between the two pull-back
/// points, leaving a short straight edge in between corners.
fn rounded_path(vertices: List(#(CartesianPoint, Float))) -> String {
  let count = list.length(vertices)
  let points =
    list.map(vertices, fn(vertex) {
      let #(point, _roundness) = vertex
      point
    })
  let previous_points =
    list.append(list.drop(points, count - 1), list.take(points, count - 1))
  let next_points = list.append(list.drop(points, 1), list.take(points, 1))

  let corners =
    list.map2(
      vertices,
      list.zip(previous_points, next_points),
      fn(vertex, neighbours) {
        let #(point, roundness) = vertex
        let #(previous, next) = neighbours
        #(
          towards(point, previous, roundness),
          point,
          towards(point, next, roundness),
        )
      },
    )

  let enter_points =
    list.map(corners, fn(corner) {
      let #(enter, _point, _exit) = corner
      enter
    })
  let next_enter_points =
    list.append(list.drop(enter_points, 1), list.take(enter_points, 1))

  let assert Ok(first_enter) = list.first(enter_points)

  let curves =
    list.map2(corners, next_enter_points, fn(corner, next_enter) {
      let #(_enter, point, exit) = corner
      "Q"
      <> point_to_string(point)
      <> " "
      <> point_to_string(exit)
      <> " L"
      <> point_to_string(next_enter)
    })
    |> string.join(" ")

  "M" <> point_to_string(first_enter) <> " " <> curves <> " Z"
}

/// A point a fraction of the way from `from` towards `to`.
fn towards(
  from: CartesianPoint,
  to: CartesianPoint,
  fraction: Float,
) -> CartesianPoint {
  CartesianPoint(
    x: from.x +. { to.x -. from.x } *. fraction,
    y: from.y +. { to.y -. from.y } *. fraction,
  )
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
