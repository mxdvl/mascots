import lustre
import lustre/element.{type Element}
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
/// the mascots on show, currently only Penelopea, but more will join her in
/// the future.
pub type Mascot {
  Penelopea(penelopea.Model)
  Lucy(lucy.Model)
}

type Message {
  PenelopeaMessage(penelopea.Message)
  LucyMessage(lucy.Message)
}

fn init(_) -> Mascot {
  Lucy(lucy.Model(7, "#ffaff3"))
}

fn update(mascot: Mascot, message: Message) -> Mascot {
  case mascot, message {
    Penelopea(model), PenelopeaMessage(sub_message) -> {
      let new_model = penelopea.update(model, sub_message)
      set_query(penelopea.to_query(new_model))
      Penelopea(new_model)
    }
    Lucy(model), LucyMessage(sub_message) -> {
      let new_model = lucy.update(model, sub_message)

      Lucy(new_model)
    }
    Penelopea(model), _ -> Penelopea(model)
    Lucy(model), _ -> Lucy(model)
  }
}

fn view(mascot: Mascot) -> Element(Message) {
  case mascot {
    Penelopea(model) -> penelopea.view(model) |> element.map(PenelopeaMessage)
    Lucy(model) -> lucy.view(model) |> element.map(LucyMessage)
  }
}
