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
    // how wide the leaves on top splay open, 0-60
    leaves: Int,
    // which eye shape is drawn inside the lenses
    eyes: Eyes,
    // vertical position of the mouth
    mouth_y: Int,
    // half-width of the mouth
    mouth_width: Int,
    // mouth curve, negative frowns, positive smiles
    mood: Int,
  )
}

fn init(_) -> Model {
  Model(
    frame: 18,
    spread: 4,
    leaves: 30,
    eyes: Dot,
    mouth_y: 2,
    mouth_width: 3,
    mood: 4,
  )
}

type Message {
  UserMovedFrame(Int)
  UserMovedSpread(Int)
  UserMovedLeaves(Int)
  UserSelectedEyes(Eyes)
  UserMovedMouthY(Int)
  UserMovedMouthWidth(Int)
  UserMovedMood(Int)
}

fn update(model: Model, message: Message) -> Model {
  case message {
    UserMovedFrame(value) -> Model(..model, frame: value)
    UserMovedSpread(value) -> Model(..model, spread: value)
    UserMovedLeaves(value) -> Model(..model, leaves: value)
    UserSelectedEyes(value) -> Model(..model, eyes: value)
    UserMovedMouthY(value) -> Model(..model, mouth_y: value)
    UserMovedMouthWidth(value) -> Model(..model, mouth_width: value)
    UserMovedMood(value) -> Model(..model, mood: value)
  }
}

const border = "rgb(11, 71, 53)"

const skin_light = "#a3d977"

const skin_mid = "#4c9a2a"

const skin_dark = "#2e6b1a"

const leaf_fill = "#6fae3e"

fn view(model: Model) -> Element(Message) {
  let frame = int.to_string(model.frame)
  let eye_x = model.frame + model.spread
  // pupils sit inset from the lens centre, towards the bridge, rather than
  // dead in the middle of the lens
  let pupil_x = eye_x - model.frame * 7 / 10
  // gap between the inner edges of the lenses, so the bridge always spans it
  let gap = eye_x - model.frame
  let half_gap = case gap < 2 {
    True -> 2
    False -> gap
  }

  element.fragment([
    html.svg(
      [
        attribute.attribute("viewBox", "-60 -66 120 132"),
        attribute.attribute("stroke-width", "2"),
        attribute.attribute("stroke-linecap", "round"),
        attribute.attribute("stroke", border),
      ],
      [
        svg.defs([], [
          svg.radial_gradient(
            [
              attribute.id("skin"),
              attribute.attribute("cx", "35%"),
              attribute.attribute("cy", "30%"),
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
        ]),
        // leaves, sprouting from the top like a little hat
        leaf(-model.leaves),
        leaf(model.leaves),
        svg.circle([
          attribute.attribute("fill", "url(#skin)"),
          attribute.attribute("r", "48"),
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
            bridge(half_gap),
            svg.circle([
              attribute.attribute("r", frame),
              attribute.attribute("cx", int.to_string(eye_x)),
              attribute.attribute("cy", "-2"),
            ]),
            eye(model.eyes, -pupil_x, is_left: True),
            eye(model.eyes, pupil_x, is_left: False),
            mouth(model.mouth_y, model.mouth_width, model.mood),
          ],
        ),
      ],
    ),
    control("Lens size", model.frame, 8, 26, UserMovedFrame),
    control("Eye spread", model.spread, 0, 14, UserMovedSpread),
    control("Leaves", model.leaves, 0, 60, UserMovedLeaves),
    control("Mouth height", model.mouth_y, -8, 16, UserMovedMouthY),
    control("Mouth width", model.mouth_width, 1, 12, UserMovedMouthWidth),
    control("Mood", model.mood, -6, 10, UserMovedMood),
    eyes_picker(model.eyes),
  ])
}

fn bridge(half_gap: Int) -> Element(Message) {
  let radius = int.to_string(half_gap + 3)
  let x = int.to_string(half_gap)
  let width = int.to_string(half_gap * 2)
  svg.path([
    attribute.attribute("fill", "none"),
    attribute.attribute(
      "d",
      "M-"
        <> x
        <> ",-4 a "
        <> radius
        <> ","
        <> radius
        <> " 0 0 1 "
        <> width
        <> ",0",
    ),
  ])
}

fn leaf(angle: Int) -> Element(Message) {
  svg.g(
    [
      attribute.attribute(
        "transform",
        "translate(0 -48) rotate(" <> int.to_string(angle) <> ")",
      ),
    ],
    [
      svg.path([
        attribute.attribute("fill", leaf_fill),
        attribute.attribute(
          "d",
          "M0,0 C -9,-10 -9,-25 0,-34 C 9,-25 9,-10 0,0 Z",
        ),
      ]),
    ],
  )
}

const eye_y = -2

fn eye(shape: Eyes, x: Int, is_left is_left: Bool) -> Element(Message) {
  case shape, is_left {
    Dot, _ -> eye_dot(x)
    Happy, _ -> eye_caret(x)
    Round, _ -> eye_ring(x, 3)
    Wide, _ -> eye_ring(x, 5)
    Flat, _ -> eye_flat(x)
    Wink, True -> eye_ring(x, 3)
    Wink, False -> eye_caret(x)
  }
}

fn eye_dot(x: Int) -> Element(Message) {
  svg.circle([
    attribute.attribute("stroke", "none"),
    attribute.attribute("fill", border),
    attribute.attribute("r", "1.6"),
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
        <> int.to_string(x - 3)
        <> ","
        <> int.to_string(eye_y + 3)
        <> " L"
        <> int.to_string(x)
        <> ","
        <> int.to_string(eye_y - 1)
        <> " L"
        <> int.to_string(x + 3)
        <> ","
        <> int.to_string(eye_y + 3),
    ),
  ])
}

fn eye_flat(x: Int) -> Element(Message) {
  svg.path([
    attribute.attribute("fill", "none"),
    attribute.attribute(
      "d",
      "M"
        <> int.to_string(x - 3)
        <> ","
        <> int.to_string(eye_y)
        <> " L"
        <> int.to_string(x + 3)
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
    eyes_button(selected, Wink, "o\\./o"),
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
