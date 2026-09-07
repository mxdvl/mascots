import gleam/list
import gleam/string
import gleeunit/should
import lustre/element
import mascots/cool_s
import mascots/pride

pub fn trans_default_test() {
  cool_s.init([])
  |> should.equal(cool_s.Model(
    width: 22,
    height: 16,
    pointiness: 21,
    colours: pride.trans,
  ))
}

pub fn add_remove_and_edit_test() {
  let model = cool_s.init([])
  let added = cool_s.update(model, cool_s.UserAddedRibbon)
  added.colours |> should.equal(list.append(pride.trans, ["ffffff"]))
  added
  |> cool_s.update(cool_s.UserRemovedRibbon(5))
  |> should.equal(model)

  model
  |> cool_s.update(cool_s.UserRemovedRibbon(1))
  |> cool_s.update(cool_s.UserChangedColour(1, "#ABCDEF"))
  |> fn(model) { model.colours }
  |> should.equal(["5bcefa", "abcdef", "f5a9b8", "5bcefa"])

  cool_s.update(model, cool_s.UserRemovedRibbon(-1)) |> should.equal(model)
  cool_s.update(model, cool_s.UserRemovedRibbon(99)) |> should.equal(model)
  cool_s.update(model, cool_s.UserChangedColour(1, "invalid"))
  |> should.equal(model)
}

pub fn ribbon_limits_test() {
  let single = cool_s.init([#("colours", "ffffff")])
  cool_s.update(single, cool_s.UserRemovedRibbon(0)) |> should.equal(single)
  let full =
    cool_s.init([#("colours", string.join(list.repeat("ffffff", 99), ","))])
  list.length(full.colours) |> should.equal(16)
  cool_s.update(full, cool_s.UserAddedRibbon) |> should.equal(full)
}

pub fn presets_and_links_test() {
  let original = cool_s.init([#("width", "36"), #("height", "24")])
  list.each(pride.presets, fn(preset) {
    let #(name, colours) = preset
    let model = cool_s.update(original, cool_s.UserSelectedPreset(name))
    model |> should.equal(cool_s.Model(..original, colours:))
    model |> cool_s.to_pairs |> cool_s.init |> should.equal(model)
    model |> cool_s.to_pairs |> list.key_find("ribbons") |> should.be_error
  })
  cool_s.update(original, cool_s.UserSelectedPreset("unknown"))
  |> should.equal(original)

  cool_s.init([#("ribbons", "2"), #("colours", "ABCDEF,invalid,123456")]).colours
  |> should.equal(["abcdef", "f5a9b8", "123456"])
}

pub fn controls_and_render_smoke_test() {
  let markup = cool_s.init([]) |> cool_s.view |> element.to_string
  markup |> string.contains("+ Add ribbon") |> should.be_true
  markup |> string.contains("Remove ribbon 3") |> should.be_true
  markup |> string.contains("type=\"color\"") |> should.be_true
  markup |> string.split("type=\"range\"") |> list.length |> should.equal(4)
  cool_s.preview() |> string.contains("fill=\"#5bcefa\"") |> should.be_true
  cool_s.preview() |> string.contains("NaN") |> should.be_false
}
