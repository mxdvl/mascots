import gleam/int
import gleam/list
import gleam/result
import gleam/uri
import lustre
import lustre/attribute
import lustre/element.{type Element}
import lustre/element/html
import lustre/element/svg
import lustre/event

@external(javascript, "./penelopea_ffi.mjs", "get_query")
fn get_query() -> String

@external(javascript, "./penelopea_ffi.mjs", "set_query")
fn set_query(query: String) -> Nil

pub fn main() {
  let app = lustre.simple(init, update, view)
  let assert Ok(_) = lustre.start(app, "#app", Nil)

  Nil
}

/// Renders the default pea as an SVG string, for offline preview/tooling use
/// (see render_preview.gleam).
pub fn preview() -> String {
  element.to_string(pea(init(Nil)))
}

pub fn preview_with(
  frame frame: Int,
  spread spread: Int,
  border_width border_width: Int,
) -> String {
  let model =
    Model(..init(Nil), frame: frame, spread: spread, border_width: border_width)
  element.to_string(pea(model))
}

type Eyes {
  Dot
  Happy
  Round
  Wide
  Flat
  Wink
}

type Model {
  Model(
    // radius of each glasses lens
    frame: Int,
    // how far apart the lenses sit from the centre
    spread: Int,
    // how wide the leaves splay apart, in degrees
    curl: Int,
    // which eye shape is drawn inside the lenses
    eyes: Eyes,
    // offset of the mouth below the bottom of the lenses
    mouth_y: Int,
    // half-width of the mouth
    mouth_width: Int,
    // mouth curve, negative frowns, positive smiles
    mood: Int,
    // thickness of the outlines, for that kawaii chunky look
    border_width: Int,
  )
}

fn init(_) -> Model {
  let defaults =
    Model(
      frame: 18,
      spread: 6,
      curl: 15,
      eyes: Dot,
      mouth_y: 0,
      mouth_width: 4,
      mood: 4,
      border_width: 4,
    )

  model_from_query(get_query(), defaults)
}

type Message {
  UserMovedFrame(Int)
  UserMovedSpread(Int)
  UserMovedCurl(Int)
  UserSelectedEyes(Eyes)
  UserMovedMouthY(Int)
  UserMovedMouthWidth(Int)
  UserMovedMood(Int)
  UserMovedBorderWidth(Int)
}

fn update(model: Model, message: Message) -> Model {
  let new_model = case message {
    UserMovedFrame(value) -> Model(..model, frame: value)
    UserMovedSpread(value) -> Model(..model, spread: value)
    UserMovedCurl(value) -> Model(..model, curl: value)
    UserSelectedEyes(value) -> Model(..model, eyes: value)
    UserMovedMouthY(value) -> Model(..model, mouth_y: value)
    UserMovedMouthWidth(value) -> Model(..model, mouth_width: value)
    UserMovedMood(value) -> Model(..model, mood: value)
    UserMovedBorderWidth(value) -> Model(..model, border_width: value)
  }

  set_query(model_to_query(new_model))
  new_model
}

fn eyes_to_string(eyes: Eyes) -> String {
  case eyes {
    Dot -> "dot"
    Happy -> "happy"
    Round -> "round"
    Wide -> "wide"
    Flat -> "flat"
    Wink -> "wink"
  }
}

fn eyes_from_string(value: String) -> Eyes {
  case value {
    "happy" -> Happy
    "round" -> Round
    "wide" -> Wide
    "flat" -> Flat
    "wink" -> Wink
    _ -> Dot
  }
}

fn model_to_query(model: Model) -> String {
  [
    #("frame", int.to_string(model.frame)),
    #("spread", int.to_string(model.spread)),
    #("curl", int.to_string(model.curl)),
    #("eyes", eyes_to_string(model.eyes)),
    #("mouth_y", int.to_string(model.mouth_y)),
    #("mouth_width", int.to_string(model.mouth_width)),
    #("mood", int.to_string(model.mood)),
    #("border_width", int.to_string(model.border_width)),
  ]
  |> uri.query_to_string
}

fn model_from_query(query: String, defaults: Model) -> Model {
  case uri.parse_query(query) {
    Error(_) -> defaults
    Ok(pairs) -> {
      let get_int = fn(key: String, min: Int, max: Int, fallback: Int) -> Int {
        pairs
        |> list.key_find(key)
        |> result.try(int.parse)
        |> result.map(int.clamp(_, min: min, max: max))
        |> result.unwrap(fallback)
      }

      let eyes =
        pairs
        |> list.key_find("eyes")
        |> result.map(eyes_from_string)
        |> result.unwrap(defaults.eyes)

      Model(
        frame: get_int("frame", 8, 26, defaults.frame),
        spread: get_int("spread", 0, 14, defaults.spread),
        curl: get_int("curl", 10, 60, defaults.curl),
        eyes: eyes,
        mouth_y: get_int("mouth_y", -4, 6, defaults.mouth_y),
        mouth_width: get_int("mouth_width", 1, 8, defaults.mouth_width),
        mood: get_int("mood", -6, 8, defaults.mood),
        border_width: get_int("border_width", 2, 8, defaults.border_width),
      )
    }
  }
}

fn view(model: Model) -> Element(Message) {
  element.fragment([
    pea(model),
    control("Lens size", model.frame, 8, 26, UserMovedFrame),
    control("Eye spread", model.spread, 0, 14, UserMovedSpread),
    control("Leaves", model.curl, 10, 60, UserMovedCurl),
    control("Border", model.border_width, 2, 8, UserMovedBorderWidth),
    control("Mouth height", model.mouth_y, -4, 6, UserMovedMouthY),
    control("Mouth width", model.mouth_width, 1, 8, UserMovedMouthWidth),
    control("Mood", model.mood, -6, 8, UserMovedMood),
    eyes_picker(model.eyes),
  ])
}

const border = "rgb(11, 71, 53)"

const skin_light = "#a3d977"

const skin_mid = "#4c9a2a"

const skin_dark = "#2e6b1a"

const leaf_fill = "#6fae3e"

/// Renders the whole pea mascot as an SVG, purely as a function of the model.
fn pea(model: Model) -> Element(Message) {
  let frame = int.to_string(model.frame)
  let eye_x = model.frame + model.spread
  // pupils sit inset from the lens centre, towards the bridge, rather than
  // dead in the middle of the lens
  let pupil_x = eye_x - model.frame * 4 / 10
  // gap between the inner edges of the lenses, so the bridge always spans
  // exactly that space (never wider, or it overshoots past the lens rims)
  let gap = eye_x - model.frame
  let half_gap = int.max(gap, 2)
  // mouth sits a small offset below the bottom of the lenses, so it can
  // never touch the glasses no matter how the lens size slider is set
  let mouth_baseline = model.frame - 2 + model.mouth_y

  html.svg(
    [
      attribute.attribute("viewBox", "-64 -96 128 168"),
      attribute.attribute("stroke-width", int.to_string(model.border_width)),
      attribute.attribute("stroke-linecap", "round"),
      attribute.attribute("stroke", border),
    ],
    [
      svg.defs([], [
        svg.radial_gradient(
          [
            attribute.id("skin"),
            attribute.attribute("cx", "50%"),
            attribute.attribute("cy", "25%"),
            attribute.attribute("r", "75%"),
          ],
          [
            svg.stop([
              attribute.attribute("offset", "0%"),
              attribute.attribute("stop-color", skin_light),
            ]),
            svg.stop([
              attribute.attribute("offset", "55%"),
              attribute.attribute("stop-color", skin_mid),
            ]),
            svg.stop([
              attribute.attribute("offset", "100%"),
              attribute.attribute("stop-color", skin_dark),
            ]),
          ],
        ),
        svg.clip_path([attribute.id("lens")], [
          svg.circle([attribute.attribute("r", frame)]),
        ]),
      ]),
      // shadow
      svg.ellipse([
        attribute.attribute("stroke", "none"),
        attribute.attribute("fill", skin_dark),
        attribute.attribute("opacity", "0.25"),
        attribute.attribute("cx", "0"),
        attribute.attribute("cy", "52"),
        attribute.attribute("rx", "32"),
        attribute.attribute("ry", "6"),
      ]),
      // leaves, sprouting from the top like a little hat
      hat(model.curl),
      svg.circle([
        attribute.attribute("fill", "url(#skin)"),
        attribute.attribute("r", "48"),
      ]),
      // a soft glossy highlight, since the light comes from above
      svg.ellipse([
        attribute.attribute("stroke", "none"),
        attribute.attribute("fill", "white"),
        attribute.attribute("opacity", "0.3"),
        attribute.attribute("cx", "0"),
        attribute.attribute("cy", "-30"),
        attribute.attribute("rx", "14"),
        attribute.attribute("ry", "8"),
      ]),
      svg.g(
        [
          attribute.attribute("data-name", "glasses"),
          attribute.attribute("fill", "none"),
        ],
        [
          svg.circle([
            attribute.attribute("r", frame),
            attribute.attribute("cx", int.to_string(-eye_x)),
            attribute.attribute("cy", "-2"),
          ]),
          lens_glass(-eye_x, model.frame),
          bridge(half_gap),
          svg.circle([
            attribute.attribute("r", frame),
            attribute.attribute("cx", int.to_string(eye_x)),
            attribute.attribute("cy", "-2"),
          ]),
          lens_glass(eye_x, model.frame),
          eye(model.eyes, -pupil_x, is_left: True),
          eye(model.eyes, pupil_x, is_left: False),
          mouth(mouth_baseline, model.mouth_width, model.mood),
        ],
      ),
    ],
  )
}

fn lens_glass(cx: Int, radius: Int) -> Element(Message) {
  let shine_width = int.to_string(int.max(radius / 5, 2))
  let x1 = int.to_string(-radius * 4 / 5)
  let y1 = int.to_string(-radius * 4 / 5)
  let x2 = int.to_string(radius / 6)
  let y2 = int.to_string(-radius / 6)
  let shadow_cx = int.to_string(radius / 2)
  let shadow_cy = int.to_string(radius / 2)
  let shadow_r = int.to_string(radius * 7 / 10)
  svg.g(
    [
      attribute.attribute(
        "transform",
        "translate(" <> int.to_string(cx) <> " -2)",
      ),
      attribute.attribute("clip-path", "url(#lens)"),
    ],
    [
      // a touch of shadow where the glass sits over the pea
      svg.circle([
        attribute.attribute("stroke", "none"),
        attribute.attribute("fill", border),
        attribute.attribute("opacity", "0.08"),
        attribute.attribute("cx", shadow_cx),
        attribute.attribute("cy", shadow_cy),
        attribute.attribute("r", shadow_r),
      ]),
      // a diagonal reflection, like light catching the lens
      svg.path([
        attribute.attribute("fill", "none"),
        attribute.attribute("stroke", "white"),
        attribute.attribute("stroke-width", shine_width),
        attribute.attribute("opacity", "0.45"),
        attribute.attribute(
          "d",
          "M" <> x1 <> "," <> y1 <> " L" <> x2 <> "," <> y2,
        ),
      ]),
    ],
  )
}

fn bridge(half_gap: Int) -> Element(Message) {
  let radius = int.to_string(half_gap + 2)
  let x = int.to_string(half_gap)
  let width = int.to_string(half_gap * 2)
  svg.path([
    attribute.attribute("fill", "none"),
    attribute.attribute("stroke-linecap", "butt"),
    attribute.attribute(
      "d",
      "M-"
        <> x
        <> ",-6 a "
        <> radius
        <> ","
        <> radius
        <> " 0 0 1 "
        <> width
        <> ",0",
    ),
  ])
}

fn hat(splay: Int) -> Element(Message) {
  svg.g([], [
    svg.path([
      attribute.attribute("fill", "none"),
      attribute.attribute("d", "M0,-48 L0,-58"),
    ]),
    leaf(-splay),
    leaf(splay),
  ])
}

fn leaf(angle: Int) -> Element(Message) {
  svg.g(
    [
      attribute.attribute(
        "transform",
        "translate(0 -56) rotate(" <> int.to_string(angle) <> ")",
      ),
    ],
    [
      svg.path([
        attribute.attribute("fill", leaf_fill),
        attribute.attribute("d", "M0,0 C -8,-6 -8,-18 0,-24 C 8,-18 8,-6 0,0 Z"),
      ]),
    ],
  )
}

const eye_y = -2

fn eye(shape: Eyes, x: Int, is_left is_left: Bool) -> Element(Message) {
  case shape, is_left {
    Dot, _ -> eye_dot(x)
    Happy, _ -> eye_caret(x)
    Round, _ -> eye_ring(x, 4)
    Wide, _ -> eye_ring(x, 6)
    Flat, _ -> eye_flat(x)
    Wink, True -> eye_ring(x, 4)
    Wink, False -> eye_caret(x)
  }
}

fn eye_dot(x: Int) -> Element(Message) {
  svg.circle([
    attribute.attribute("stroke", "none"),
    attribute.attribute("fill", border),
    attribute.attribute("r", "2.4"),
    attribute.attribute("cx", int.to_string(x)),
    attribute.attribute("cy", int.to_string(eye_y)),
  ])
}

fn eye_ring(x: Int, r: Int) -> Element(Message) {
  svg.circle([
    attribute.attribute("fill", "none"),
    attribute.attribute("r", int.to_string(r)),
    attribute.attribute("cx", int.to_string(x)),
    attribute.attribute("cy", int.to_string(eye_y)),
  ])
}

fn eye_caret(x: Int) -> Element(Message) {
  svg.path([
    attribute.attribute("fill", "none"),
    attribute.attribute(
      "d",
      "M"
        <> int.to_string(x - 4)
        <> ","
        <> int.to_string(eye_y + 4)
        <> " L"
        <> int.to_string(x)
        <> ","
        <> int.to_string(eye_y - 2)
        <> " L"
        <> int.to_string(x + 4)
        <> ","
        <> int.to_string(eye_y + 4),
    ),
  ])
}

fn eye_flat(x: Int) -> Element(Message) {
  svg.path([
    attribute.attribute("fill", "none"),
    attribute.attribute(
      "d",
      "M"
        <> int.to_string(x - 4)
        <> ","
        <> int.to_string(eye_y)
        <> " L"
        <> int.to_string(x + 4)
        <> ","
        <> int.to_string(eye_y),
    ),
  ])
}

fn mouth(y: Int, half_width: Int, mood: Int) -> Element(Message) {
  let x1 = int.to_string(-half_width)
  let x2 = int.to_string(half_width)
  let baseline = int.to_string(y)
  let midpoint = int.to_string(y + mood)
  svg.path([
    attribute.attribute("fill", "none"),
    attribute.attribute(
      "d",
      "M"
        <> x1
        <> ","
        <> baseline
        <> " Q0,"
        <> midpoint
        <> " "
        <> x2
        <> ","
        <> baseline,
    ),
  ])
}

fn eyes_picker(selected: Eyes) -> Element(Message) {
  html.div([attribute.attribute("role", "group"), attribute.class("eyes")], [
    eyes_button(selected, Dot, "._."),
    eyes_button(selected, Happy, "^.^"),
    eyes_button(selected, Round, "o.o"),
    eyes_button(selected, Wide, "O.O"),
    eyes_button(selected, Flat, "-.-"),
    eyes_button(selected, Wink, "o.^"),
  ])
}

fn eyes_button(selected: Eyes, shape: Eyes, label: String) -> Element(Message) {
  html.button(
    [
      event.on_click(UserSelectedEyes(shape)),
      attribute.attribute("aria-pressed", case selected == shape {
        True -> "true"
        False -> "false"
      }),
    ],
    [html.text(label)],
  )
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
