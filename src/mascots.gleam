import lustre
import lustre/element.{type Element}
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
}

type Message {
  PenelopeaMessage(penelopea.Message)
}

fn init(_) -> Mascot {
  Penelopea(penelopea.init(get_query()))
}

fn update(mascot: Mascot, message: Message) -> Mascot {
  case mascot, message {
    Penelopea(model), PenelopeaMessage(sub_message) -> {
      let new_model = penelopea.update(model, sub_message)
      set_query(penelopea.to_query(new_model))
      Penelopea(new_model)
    }
  }
}

fn view(mascot: Mascot) -> Element(Message) {
  case mascot {
    Penelopea(model) -> penelopea.view(model) |> element.map(PenelopeaMessage)
  }
}
