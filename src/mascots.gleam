import gleam/list
import gleam/result
import gleam/uri
import lustre
import lustre/attribute
import lustre/element.{type Element}
import lustre/element/html
import lustre/event
import mascots/lucy
import mascots/penelopea

@external(javascript, "./mascots_ffi.mjs", "get_query")
fn get_query() -> String

@external(javascript, "./mascots_ffi.mjs", "set_query")
fn set_query(query: String) -> Nil

pub fn main() {
  let app = lustre.simple(init, update, view)
  let assert Ok(_) = lustre.start(app, "#app", Nil)

  Nil
}

/// A mini website about SVG mascots. The model is a discriminated union of
/// the mascots on show
pub type Mascot {
  Penelopea(penelopea.Model)
  Lucy(lucy.Model)
}

type Message {
  UserSelectedLucy
  UserSelectedPenelopea
  PenelopeaMessage(penelopea.Message)
  LucyMessage(lucy.Message)
}

/// Works out which mascot a shared link is for, by reading the `mascot`
/// query parameter - one of the two mascots' own `id` constants - falling
/// back to Lucy when it's missing or unrecognised.
fn init(_) -> Mascot {
  let query = get_query()
  case selected_id(query) {
    id if id == penelopea.id -> Penelopea(penelopea.init(query))
    _ -> Lucy(lucy.init(query))
  }
}

fn selected_id(query: String) -> String {
  uri.parse_query(query)
  |> result.try(list.key_find(_, "mascot"))
  |> result.unwrap(lucy.id)
}

fn update(mascot: Mascot, message: Message) -> Mascot {
  let new_mascot = case mascot, message {
    _, UserSelectedLucy -> Lucy(lucy.init(get_query()))
    _, UserSelectedPenelopea -> Penelopea(penelopea.init(get_query()))
    Penelopea(model), PenelopeaMessage(sub_message) ->
      Penelopea(penelopea.update(model, sub_message))
    Lucy(model), LucyMessage(sub_message) ->
      Lucy(lucy.update(model, sub_message))
    Penelopea(_), _ | Lucy(_), _ -> mascot
  }
  persist(new_mascot)
  new_mascot
}

/// Saves the current mascot to the URL, tagged with its `id`, so reloading
/// or sharing the link brings back the same mascot in the same state.
fn persist(mascot: Mascot) -> Nil {
  case mascot {
    Lucy(model) ->
      set_query("mascot=" <> lucy.id <> "&" <> lucy.to_query(model))
    Penelopea(model) ->
      set_query("mascot=" <> penelopea.id <> "&" <> penelopea.to_query(model))
  }
}

fn view(mascot: Mascot) -> Element(Message) {
  element.fragment([
    tabs(mascot),
    case mascot {
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
    PenelopeaMessage(_) | LucyMessage(_) -> #("…", "")
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
