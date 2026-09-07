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
  Model(width: Float, height: Float, pointiness: Float, colours: List(String))
}

pub type Message {
  UserMovedWidth(Float)
  UserMovedHeight(Float)
  UserMovedPointiness(Float)
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
  Model(width: 22.0, height: 16.0, pointiness: 21.0, colours: pride.trans)
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

// Sliders and older URLs can omit the decimal point required by float.parse.
fn parse_dimension(value: String) -> Result(Float, Nil) {
  case float.parse(value) {
    Ok(parsed) -> Ok(parsed)
    Error(_) -> float.parse(value <> ".0")
  }
}

/// Restores the palette and dimensions. Each colour defines one ribbon.
pub fn init(pairs: List(#(String, String))) -> Model {
  let fallback = defaults()
  let get_float = fn(
    key: String,
    minimum: Float,
    maximum: Float,
    default: Float,
  ) -> Float {
    pairs
    |> list.key_find(key)
    |> result.try(parse_dimension)
    |> result.map(float.clamp(_, min: minimum, max: maximum))
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
    width: get_float("width", 14.0, 46.0, fallback.width),
    height: get_float("height", 8.0, 28.0, fallback.height),
    pointiness: get_float("pointiness", 0.0, 40.0, fallback.pointiness),
    colours:,
  )
}

pub fn update(model: Model, message: Message) -> Model {
  case message {
    UserMovedWidth(width) ->
      Model(..model, width: float.clamp(width, 14.0, 46.0))
    UserMovedHeight(height) ->
      Model(..model, height: float.clamp(height, 8.0, 28.0))
    UserMovedPointiness(pointiness) ->
      Model(..model, pointiness: float.clamp(pointiness, 0.0, 40.0))
    UserAddedRibbon -> {
      let colours =
        list.append(model.colours, ["ffffff"]) |> list.take(max_ribbons)
      Model(..model, colours:)
    }
    UserFlippedRibbons -> Model(..model, colours: list.reverse(model.colours))
    UserRemovedRibbon(index) ->
      case model.colours {
        [] | [_] -> model
        _ if index < 0 -> model
        _ -> {
          let #(before, remaining) = list.split(model.colours, at: index)
          Model(..model, colours: list.append(before, list.drop(remaining, 1)))
        }
      }
    UserChangedColour(index, colour) -> {
      let colours =
        list.index_map(model.colours, fn(previous, colour_index) {
          case colour_index == index {
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

/// Share whole-number dimensions without rounding the live model.
pub fn to_pairs(model: Model) -> List(#(String, String)) {
  [
    #("width", format_dimension(model.width)),
    #("height", format_dimension(model.height)),
    #("pointiness", format_dimension(model.pointiness)),

    #("colours", string.join(model.colours, ",")),
  ]
}

fn format_dimension(value: Float) -> String {
  value
  |> float.to_precision(0)
  |> float.to_string
  |> string.remove_suffix(".0")
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
    control("Width", model.width, 14.0, 46.0, 2.0, UserMovedWidth),
    control("Height", model.height, 8.0, 28.0, 1.0, UserMovedHeight),
    control("Pointiness", model.pointiness, 0.0, 40.0, 1.0, UserMovedPointiness),
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
  let #(back, front) =
    model.colours
    |> list.index_map(fn(colour, index) {
      let left = boundary(model, int.to_float(index) /. count)
      let right = boundary(model, int.to_float(index + 1) /. count)
      #(strip(ends(left), ends(right), colour), strip(left, right, colour))
    })
    |> list.unzip

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
  let width = model.width
  let height = model.height
  let seam = [
    Point(0.0, 0.0 -. height *. 1.5),
    Point(0.0, 0.0 -. height *. 0.5),
    Point(width, height *. 0.5),
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
        attribute.attribute("stroke-width", float.to_string(0.8)),
        attribute.attribute("stroke-linejoin", "round"),
        attribute.attribute("stroke-linecap", "round"),
      ]),
    ],
  )
}

/// The two edges of the folded band interpolate into parallel lanes.
/// The lane order reverses around the bottom fold to keep every ribbon
/// connected to its own colour, including along the hidden back diagonal.
fn boundary(model: Model, fraction: Float) -> List(Point) {
  let width = model.width
  let height = model.height
  let pointiness = model.pointiness
  let top = width *. fraction
  let bottom = width *. { 1.0 -. fraction }
  [
    Point(top, 0.0 -. height *. 0.5),
    Point(top, 0.0 -. height *. 1.5),
    Point(0.0, 0.0 -. height *. 1.5 -. pointiness *. fraction),
    Point(0.0 -. top, 0.0 -. height *. 1.5),
    Point(0.0 -. top, 0.0 -. height *. 0.5),
    Point(bottom, height *. 0.5),
    Point(bottom, height *. 1.5),
    Point(0.0, height *. 1.5 +. pointiness *. { 1.0 -. fraction }),
    Point(0.0 -. bottom, height *. 1.5),
    Point(0.0 -. bottom, height *. 0.5),
  ]
}

fn ends(points: List(Point)) -> List(Point) {
  case list.first(points), list.last(points) {
    Ok(first), Ok(last) -> [last, first]
    _, _ -> []
  }
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
pub fn at(model: Model, fraction: Float) -> Point {
  let segments = model |> boundary(0.5) |> list.window_by_2
  let lengths = {
    use segment <- list.map(segments)
    let delta_x = segment.1.x -. segment.0.x
    let delta_y = segment.1.y -. segment.0.y
    float.square_root(delta_x *. delta_x +. delta_y *. delta_y)
    |> result.unwrap(0.0)
  }
  walk(segments, lengths, fraction *. float.sum(lengths))
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
  value: Float,
  minimum: Float,
  maximum: Float,
  step: Float,
  update: fn(Float) -> Message,
) -> Element(Message) {
  html.label([], [
    html.span([], [html.text(label)]),
    html.input([
      attribute.type_("range"),
      attribute.step(float.to_string(step)),
      attribute.min(float.to_string(minimum)),
      attribute.max(float.to_string(maximum)),
      value |> float.to_string |> attribute.value,
      event.on_input(fn(input) {
        input |> parse_dimension |> result.unwrap(value) |> update
      }),
    ]),
  ])
}
