import gleam/list
import gleam/result
import gleam/uri
import lustre
import lustre/attribute
import lustre/effect.{type Effect}
import lustre/element.{type Element}
import lustre/element/html
import lustre/event
import mascots/lucy
import mascots/penelopea

@external(javascript, "./mascots_ffi.mjs", "get_query")
fn get_query() -> String {
  ""
}

@external(javascript, "./mascots_ffi.mjs", "set_query")
fn set_query(_query: String) -> Nil {
  Nil
}

@external(javascript, "./mascots_ffi.mjs", "set_timeout")
fn set_timeout(_delay: Int, _callback: fn() -> Nil) -> Nil {
  Nil
}

pub fn main() {
  let app = lustre.application(init, update, view)
  let assert Ok(_) = lustre.start(app, "#app", Nil)

  Nil
}

/// A mini website about SVG mascots. The model is a discriminated union of
/// the mascots on show
pub type Mascot {
  Penelopea(penelopea.Model)
  Lucy(lucy.Model)
}

pub type Model {
  Model(mascot: Mascot, generation: Int)
}

type Message {
  UserSelectedLucy
  UserSelectedPenelopea
  PenelopeaMessage(penelopea.Message)
  LucyMessage(lucy.Message)
  PersistDue(generation: Int)
}

/// Works out which mascot a shared link is for, by reading the `mascot`
/// query parameter - one of the two mascots' own `id` constants - falling
/// back to Lucy when it's missing or unrecognised.
fn init(_) -> #(Model, Effect(Message)) {
  let pairs = current_pairs()
  let mascot = case list.key_find(pairs, "mascot") {
    Ok(id) if id == penelopea.id -> Penelopea(penelopea.init(pairs))
    _ -> Lucy(lucy.init(pairs))
  }
  #(Model(mascot:, generation: 0), effect.none())
}

/// The URL's current query, parsed into pairs
fn current_pairs() -> List(#(String, String)) {
  get_query()
  |> uri.parse_query
  |> result.unwrap([])
}

fn update(model: Model, message: Message) -> #(Model, Effect(Message)) {
  case message {
    // Only persist if no newer change has bumped the generation since this
    // was scheduled - otherwise a more recent `PersistDue` is already on its
    // way, so this stale one is simply dropped. This is what debounces the
    // writes to the URL.
    PersistDue(generation) if generation == model.generation -> {
      persist(model.mascot)
      #(model, effect.none())
    }
    PersistDue(_) -> #(model, effect.none())

    _ -> {
      let mascot = case model.mascot, message {
        _, UserSelectedLucy -> Lucy(lucy.init(current_pairs()))
        _, UserSelectedPenelopea -> Penelopea(penelopea.init(current_pairs()))
        Penelopea(model), PenelopeaMessage(sub_message) ->
          Penelopea(penelopea.update(model, sub_message))
        Lucy(model), LucyMessage(sub_message) ->
          Lucy(lucy.update(model, sub_message))
        mascot, _ -> mascot
      }
      let generation = model.generation + 1
      #(Model(mascot:, generation:), schedule_persist(generation))
    }
  }
}

/// Schedules a `PersistDue` message tagged with `generation`, to arrive
/// after some time (see `update` for how that debounces things).
fn schedule_persist(generation: Int) -> Effect(Message) {
  use dispatch <- effect.from
  use <- set_timeout(240)
  PersistDue(generation) |> dispatch
}

/// Saves the current mascot to the URL, tagged with its `id`, so reloading
/// or sharing the link brings back the same mascot in the same state.
fn persist(mascot: Mascot) -> Nil {
  let pairs = case mascot {
    Lucy(model) -> [#("mascot", lucy.id), ..lucy.to_pairs(model)]
    Penelopea(model) -> [#("mascot", penelopea.id), ..penelopea.to_pairs(model)]
  }
  set_query(uri.query_to_string(pairs))
}

fn view(model: Model) -> Element(Message) {
  element.fragment([
    tabs(model.mascot),
    case model.mascot {
      Penelopea(model) -> penelopea.view(model) |> element.map(PenelopeaMessage)
      Lucy(model) -> lucy.view(model) |> element.map(LucyMessage)
    },
  ])
}

fn tabs(selected: Mascot) -> Element(Message) {
  html.div([attribute.attribute("role", "tablist"), attribute.class("tabs")], [
    tab_button(selected, UserSelectedLucy),
    tab_button(selected, UserSelectedPenelopea),
  ])
}

fn tab_button(selected: Mascot, message: Message) -> Element(Message) {
  let #(label, controls) = case message {
    UserSelectedLucy -> #("Lucy", lucy.id)
    UserSelectedPenelopea -> #("Penelopea", penelopea.id)
    _ -> #("…", "")
  }
  html.button(
    [
      attribute.attribute("role", "tab"),
      attribute.attribute("aria-controls", controls),
      attribute.attribute("aria-selected", case selected, message {
        Lucy(_), UserSelectedLucy -> "true"
        Penelopea(_), UserSelectedPenelopea -> "true"
        _, _ -> "false"
      }),
      event.on_click(message),
    ],
    [html.text(label)],
  )
}
