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
import mascots/pride

/// Each colour is one ribbon, in order along the folded Cool S band.
pub type Model {
  Model(width: Int, height: Int, pointiness: Int, colours: List(String))
}

pub type Message {
  UserMovedWidth(Int)
  UserMovedHeight(Int)
  UserMovedPointiness(Int)
  UserAddedRibbon
  UserFlippedRibbons
  UserRemovedRibbon(index: Int)
  UserChangedColour(index: Int, colour: String)
  UserSelectedPreset(String)
}

pub type Point {
  Point(x: Float, y: Float)
}

pub const id = "cool_s"

const fold_mask_id = "cool_s_folds"

const max_ribbons = 16

fn defaults() -> Model {
  Model(width: 22, height: 16, pointiness: 21, colours: pride.trans)
}

fn normalise_colour(value: String, fallback: String) -> String {
  let value = value |> string.remove_prefix("#") |> string.lowercase
  let valid =
    string.length(value) == 6
    && list.all(string.to_graphemes(value), fn(digit) {
      string.contains("0123456789abcdef", digit)
    })

  case valid {
    True -> value
    False -> fallback
  }
}

/// Restores the palette and dimensions. Each colour defines one ribbon.
pub fn init(pairs: List(#(String, String))) -> Model {
  let fallback = defaults()
  let get_int = fn(key: String, min: Int, max: Int, default: Int) -> Int {
    pairs
    |> list.key_find(key)
    |> result.try(int.parse)
    |> result.map(int.clamp(_, min: min, max: max))
    |> result.unwrap(default)
  }
  let colours =
    pairs
    |> list.key_find("colours")
    |> result.map(string.split(_, ","))
    |> result.unwrap(fallback.colours)
    |> list.take(max_ribbons)
    |> list.index_map(fn(colour, index) {
      let default =
        fallback.colours
        |> list.drop(index)
        |> list.first
        |> result.unwrap("ffffff")
      normalise_colour(colour, default)
    })

  Model(
    width: get_int("width", 14, 46, fallback.width),
    height: get_int("height", 8, 28, fallback.height),
    pointiness: get_int("pointiness", 0, 40, fallback.pointiness),
    colours:,
  )
}

pub fn update(model: Model, message: Message) -> Model {
  case message {
    UserMovedWidth(width) -> Model(..model, width: int.clamp(width, 14, 46))
    UserMovedHeight(height) -> Model(..model, height: int.clamp(height, 8, 28))
    UserMovedPointiness(pointiness) ->
      Model(..model, pointiness: int.clamp(pointiness, 0, 40))
    UserAddedRibbon -> {
      let colours =
        list.append(model.colours, ["ffffff"]) |> list.take(max_ribbons)
      Model(..model, colours:)
    }
    UserFlippedRibbons -> Model(..model, colours: list.reverse(model.colours))
    UserRemovedRibbon(index) ->
      case model.colours {
        [] | [_] -> model
        _ -> Model(..model, colours: remove_colour(model.colours, index))
      }
    UserChangedColour(index, colour) -> {
      let colours =
        list.index_map(model.colours, fn(previous, i) {
          case i == index {
            True -> normalise_colour(colour, previous)
            False -> previous
          }
        })
      Model(..model, colours:)
    }
    UserSelectedPreset(name) ->
      case list.key_find(pride.presets, name) {
        Ok(colours) -> Model(..model, colours:)
        Error(_) -> model
      }
  }
}

fn remove_colour(colours: List(String), index: Int) -> List(String) {
  case colours, index {
    [], _ -> []
    [_, ..rest], 0 -> rest
    [colour, ..rest], _ -> [colour, ..remove_colour(rest, index - 1)]
  }
}

pub fn to_pairs(model: Model) -> List(#(String, String)) {
  [
    #("width", int.to_string(model.width)),
    #("height", int.to_string(model.height)),
    #("pointiness", int.to_string(model.pointiness)),

    #("colours", string.join(model.colours, ",")),
  ]
}

/// Run `gleam run -m render_preview` for an offline SVG preview.
pub fn preview() -> String {
  element.to_string(cool_s(defaults()))
}

pub fn view(model: Model) -> Element(Message) {
  let count = list.length(model.colours)
  element.fragment([
    cool_s(model),
    html.fieldset([attribute.class("pride-presets")], [
      html.legend([], [html.text("Flag palettes")]),
      html.div(
        [],
        list.map(pride.presets, fn(preset) {
          let #(name, colours) = preset
          html.button(
            [
              attribute.type_("button"),
              attribute.attribute(
                "aria-pressed",
                case model.colours == colours {
                  True -> "true"
                  False -> "false"
                },
              ),
              event.on_click(UserSelectedPreset(name)),
            ],
            [
              html.span(
                [
                  attribute.class("flag-swatch"),
                  attribute.attribute("aria-hidden", "true"),
                ],
                list.map(colours, fn(colour) {
                  html.span(
                    [
                      attribute.attribute(
                        "style",
                        "background-color: #" <> colour,
                      ),
                    ],
                    [],
                  )
                }),
              ),
              html.text(name),
            ],
          )
        }),
      ),
    ]),
    control("Width", model.width, 14, 46, 2, UserMovedWidth),
    control("Height", model.height, 8, 28, 1, UserMovedHeight),
    control("Pointiness", model.pointiness, 0, 40, 1, UserMovedPointiness),
    html.fieldset([attribute.class("ribbon-controls")], [
      html.legend([], [html.text("Ribbons (" <> int.to_string(count) <> ")")]),
      element.fragment(
        list.index_map(model.colours, fn(colour, index) {
          colour_control(colour, index, count == 1)
        }),
      ),
      html.div([attribute.class("ribbon-actions")], [
        html.button(
          [
            attribute.type_("button"),
            attribute.disabled(count >= max_ribbons),
            event.on_click(UserAddedRibbon),
          ],
          [html.text("+ Add ribbon")],
        ),
        html.button(
          [
            attribute.type_("button"),
            attribute.disabled(count < 2),
            attribute.attribute("title", "Reverse the ribbon colour order"),
            event.on_click(UserFlippedRibbons),
          ],
          [html.text("Flip in / out")],
        ),
      ]),
    ]),
  ])
}

/// The back diagonal is painted first. The folded band then crosses over
/// it, giving the six-column doodle its characteristic interlocking centre.
fn cool_s(model: Model) -> Element(Message) {
  let count = int.to_float(list.length(model.colours))
  let ribbons =
    list.index_map(model.colours, fn(colour, index) {
      let from = int.to_float(index) /. count
      let to = int.to_float(index + 1) /. count
      #(colour, boundary(model, from), boundary(model, to))
    })
  let back =
    list.map(ribbons, fn(ribbon) {
      let #(colour, left, right) = ribbon
      strip(ends(left), ends(right), colour)
    })
  let front =
    list.map(ribbons, fn(ribbon) {
      let #(colour, left, right) = ribbon
      strip(left, right, colour)
    })

  html.svg(
    [
      attribute.id(id),
      attribute.attribute("viewBox", "-64 -90 128 180"),
      attribute.attribute("role", "img"),
      attribute.attribute(
        "aria-label",
        "Cool S with "
          <> int.to_string(list.length(model.colours))
          <> " coloured ribbons",
      ),
    ],
    [
      svg.defs([], [fold_mask(model)]),
      svg.g(
        [attribute.attribute("mask", "url(#" <> fold_mask_id <> ")")],
        list.append(back, front),
      ),
    ],
  )
}

/// Cut through both ribbon layers so the folds reveal any background,
/// including when the SVG is exported onto a different colour.
fn fold_mask(model: Model) -> Element(Message) {
  let w = int.to_float(model.width)
  let h = int.to_float(model.height)
  let seam = [
    Point(0.0, 0.0 -. h *. 1.5),
    Point(0.0, 0.0 -. h *. 0.5),
    Point(w, h *. 0.5),
  ]
  let opposite =
    list.map(seam, fn(point) { Point(0.0 -. point.x, 0.0 -. point.y) })

  svg.mask(
    [
      attribute.id(fold_mask_id),
      attribute.attribute("maskUnits", "userSpaceOnUse"),
      attribute.attribute("maskContentUnits", "userSpaceOnUse"),
      attribute.attribute("mask-type", "luminance"),
      attribute.attribute("x", "-64"),
      attribute.attribute("y", "-90"),
      attribute.attribute("width", "128"),
      attribute.attribute("height", "180"),
    ],
    [
      svg.rect([
        attribute.attribute("x", "-64"),
        attribute.attribute("y", "-90"),
        attribute.attribute("width", "128"),
        attribute.attribute("height", "180"),
        attribute.attribute("fill", "white"),
      ]),
      svg.path([
        attribute.attribute("d", path(seam) <> " " <> path(opposite)),
        attribute.attribute("fill", "none"),
        attribute.attribute("stroke", "black"),
        attribute.attribute("stroke-width", "0.8"),
        attribute.attribute("stroke-linejoin", "round"),
        attribute.attribute("stroke-linecap", "round"),
      ]),
    ],
  )
}

/// The two edges of the folded band interpolate into parallel lanes.
/// The lane order reverses around the bottom fold to keep every ribbon
/// connected to its own colour, including along the hidden back diagonal.
fn boundary(model: Model, t: Float) -> List(Point) {
  let w = int.to_float(model.width)
  let h = int.to_float(model.height)
  let p = int.to_float(model.pointiness)
  let top = w *. t
  let bottom = w *. { 1.0 -. t }
  [
    Point(top, 0.0 -. h *. 0.5),
    Point(top, 0.0 -. h *. 1.5),
    Point(0.0, 0.0 -. h *. 1.5 -. p *. t),
    Point(0.0 -. top, 0.0 -. h *. 1.5),
    Point(0.0 -. top, 0.0 -. h *. 0.5),
    Point(bottom, h *. 0.5),
    Point(bottom, h *. 1.5),
    Point(0.0, h *. 1.5 +. p *. { 1.0 -. t }),
    Point(0.0 -. bottom, h *. 1.5),
    Point(0.0 -. bottom, h *. 0.5),
  ]
}

fn ends(points: List(Point)) -> List(Point) {
  let assert [first, ..] = points
  let assert [last, ..] = list.reverse(points)
  [last, first]
}

fn strip(
  left: List(Point),
  right: List(Point),
  colour: String,
) -> Element(Message) {
  svg.path([
    attribute.attribute(
      "d",
      path(list.append(left, list.reverse(right))) <> " Z",
    ),
    attribute.attribute("fill", "#" <> colour),
  ])
}

/// Arc-length position along the front band, from the upper-right fold
/// around the S to the lower-left fold. Its midpoint is the central crossing.
pub fn at(model: Model, t: Float) -> Point {
  let points = boundary(model, 0.5)
  let segments = list.zip(points, list.drop(points, 1))
  let lengths =
    list.map(segments, fn(segment) {
      let dx = segment.1.x -. segment.0.x
      let dy = segment.1.y -. segment.0.y
      let assert Ok(length) = float.square_root(dx *. dx +. dy *. dy)
      length
    })
  walk(segments, lengths, t *. float.sum(lengths))
}

fn walk(
  segments: List(#(Point, Point)),
  lengths: List(Float),
  target: Float,
) -> Point {
  case segments, lengths {
    [#(from, to), ..rest_segments], [length, ..rest_lengths] ->
      case target <=. length || rest_segments == [] {
        True -> {
          let fraction = case length >. 0.0 {
            True -> float.clamp(target /. length, min: 0.0, max: 1.0)
            False -> 0.0
          }
          Point(
            from.x +. { to.x -. from.x } *. fraction,
            from.y +. { to.y -. from.y } *. fraction,
          )
        }
        False -> walk(rest_segments, rest_lengths, target -. length)
      }
    _, _ -> Point(0.0, 0.0)
  }
}

fn path(points: List(Point)) -> String {
  case points {
    [] -> ""
    [first, ..rest] ->
      "M"
      <> format_point(first)
      <> " L"
      <> { rest |> list.map(format_point) |> string.join(" ") }
  }
}

fn format_point(point: Point) -> String {
  round(point.x) <> "," <> round(point.y)
}

fn round(value: Float) -> String {
  value |> float.to_precision(3) |> float.to_string
}

fn colour_control(
  colour: String,
  index: Int,
  only_ribbon: Bool,
) -> Element(Message) {
  let name = "Ribbon " <> int.to_string(index + 1)
  html.div([attribute.class("ribbon-row")], [
    html.label([], [
      html.span([], [html.text(name)]),
      html.input([
        attribute.type_("color"),
        attribute.value("#" <> colour),
        event.on_input(UserChangedColour(index, _)),
      ]),
    ]),
    html.button(
      [
        attribute.type_("button"),
        attribute.attribute("aria-label", "Remove " <> string.lowercase(name)),
        attribute.disabled(only_ribbon),
        event.on_click(UserRemovedRibbon(index)),
      ],
      [html.text("Remove")],
    ),
  ])
}

fn control(
  label: String,
  value: Int,
  min: Int,
  max: Int,
  step: Int,
  update: fn(Int) -> Message,
) -> Element(Message) {
  html.label([], [
    html.span([], [html.text(label)]),
    html.input([
      attribute.type_("range"),
      attribute.step(int.to_string(step)),
      attribute.min(int.to_string(min)),
      attribute.max(int.to_string(max)),
      value |> int.to_string |> attribute.value,
      event.on_input(fn(input) {
        input |> int.parse |> result.unwrap(value) |> update
      }),
    ]),
  ])
}
