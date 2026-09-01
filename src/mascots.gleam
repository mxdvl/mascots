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

fn init(_) -> Mascot {
  Lucy(lucy.Model(7, "#ffaff3"))
}

fn update(mascot: Mascot, message: Message) -> Mascot {
  case mascot, message {
    _, UserSelectedLucy -> Lucy(lucy.Model(7, "#ffaff3"))
    _, UserSelectedPenelopea -> Penelopea(penelopea.init(get_query()))
    Penelopea(model), PenelopeaMessage(sub_message) -> {
      let new_model = penelopea.update(model, sub_message)
      set_query(penelopea.to_query(new_model))
      Penelopea(new_model)
    }
    Lucy(model), LucyMessage(sub_message) ->
      Lucy(lucy.update(model, sub_message))
    Penelopea(_), _ | Lucy(_), _ -> mascot
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
  let label = case message {
    UserSelectedLucy -> "Lucy"
    UserSelectedPenelopea -> "Penelopea"
    _ -> "…"
  }
  html.button(
    [
      attribute.attribute("role", "tab"),
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
