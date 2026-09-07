import gleam/list
import gleam/string
import gleam/uri
import gleeunit/should
import lustre/element
import mascots/cool_s
import mascots/pride

pub fn trans_default_test() {
  cool_s.init([])
  |> should.equal(cool_s.Model(
    width: 22.0,
    height: 16.0,
    pointiness: 21.0,
    colours: pride.trans,
    flips: 0,
  ))
}

pub fn float_geometry_test() {
  let defaults = cool_s.init([])
  let fractional =
    cool_s.init([
      #("width", "22.5"),
      #("height", "16.25"),
      #("pointiness", "21.75"),
    ])
  fractional
  |> should.equal(
    cool_s.Model(..defaults, width: 22.5, height: 16.25, pointiness: 21.75),
  )
  let pairs = cool_s.to_pairs(fractional)
  list.key_find(pairs, "width") |> should.equal(Ok("23"))
  list.key_find(pairs, "height") |> should.equal(Ok("16"))
  list.key_find(pairs, "pointiness") |> should.equal(Ok("22"))
  pairs
  |> cool_s.init
  |> should.equal(
    cool_s.Model(..defaults, width: 23.0, height: 16.0, pointiness: 22.0),
  )

  defaults
  |> cool_s.update(cool_s.UserMovedWidth(22.5))
  |> cool_s.update(cool_s.UserMovedHeight(16.25))
  |> cool_s.update(cool_s.UserMovedPointiness(21.75))
  |> should.equal(fractional)

  cool_s.init([#("width", "36"), #("height", "24"), #("pointiness", "30")])
  |> should.equal(
    cool_s.Model(..defaults, width: 36.0, height: 24.0, pointiness: 30.0),
  )

  cool_s.init([
    #("width", "100.5"),
    #("height", "-1.25"),
    #("pointiness", "99.5"),
  ])
  |> should.equal(
    cool_s.Model(..defaults, width: 46.0, height: 8.0, pointiness: 40.0),
  )

  cool_s.init([#("width", "invalid"), #("height", "NaN"), #("pointiness", "")])
  |> should.equal(defaults)
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

pub fn clockwise_rotation_test() {
  let original = cool_s.init([#("colours", "123456,abcdef,ffffff")])
  let once = cool_s.update(original, cool_s.UserFlipped)
  once |> should.equal(cool_s.Model(..original, flips: 1))
  let twice = cool_s.update(once, cool_s.UserFlipped)
  twice |> should.equal(cool_s.Model(..original, flips: 2))
  let thrice = cool_s.update(twice, cool_s.UserFlipped)
  thrice |> should.equal(cool_s.Model(..original, flips: 3))

  list.each([#(once, "180"), #(twice, "360"), #(thrice, "540")], fn(rotation) {
    let #(model, degrees) = rotation
    model
    |> cool_s.view
    |> element.to_string
    |> string.contains("transform: rotate(" <> degrees <> "deg)")
    |> should.be_true
    model |> cool_s.to_pairs |> should.equal(cool_s.to_pairs(original))
    model |> cool_s.to_pairs |> cool_s.init |> should.equal(original)
  })

  cool_s.init([#("flips", "5")]).flips |> should.equal(0)
  once
  |> cool_s.update(cool_s.UserMovedWidth(30.0))
  |> cool_s.update(cool_s.UserSelectedPreset("Rainbow"))
  |> fn(model) { model.flips }
  |> should.equal(1)
}

pub fn swap_adjacent_colours_test() {
  let model =
    cool_s.init([#("colours", "111111,222222,333333,444444")])
    |> cool_s.update(cool_s.UserFlipped)

  list.each(
    [
      #(0, ["222222", "111111", "333333", "444444"]),
      #(1, ["111111", "333333", "222222", "444444"]),
      #(2, ["111111", "222222", "444444", "333333"]),
    ],
    fn(swap) {
      let #(index, colours) = swap
      let swapped = cool_s.update(model, cool_s.UserSwappedColours(index))
      swapped |> should.equal(cool_s.Model(..model, colours:))
      swapped
      |> cool_s.update(cool_s.UserSwappedColours(index))
      |> should.equal(model)
    },
  )
  list.each([-1, 3, 4, 99], fn(index) {
    cool_s.update(model, cool_s.UserSwappedColours(index))
    |> should.equal(model)
  })
  let single = cool_s.init([#("colours", "ffffff")])
  cool_s.update(single, cool_s.UserSwappedColours(0)) |> should.equal(single)
  let empty = cool_s.Model(..model, colours: [])
  cool_s.update(empty, cool_s.UserSwappedColours(0)) |> should.equal(empty)
}

pub fn hash_free_colour_links_test() {
  let model =
    cool_s.init([#("colours", "#ABCDEF,#123456,ffffff")])
    |> cool_s.update(cool_s.UserChangedColour(2, "#AABBCC"))
    |> cool_s.update(cool_s.UserSwappedColours(0))
  let pairs = cool_s.to_pairs(model)
  pairs
  |> list.filter(fn(pair) { pair.0 == "colours" })
  |> should.equal([
    #("colours", "123456"),
    #("colours", "abcdef"),
    #("colours", "aabbcc"),
  ])

  let query = uri.query_to_string(pairs)
  query |> string.contains("%23") |> should.be_false
  query |> string.contains("#") |> should.be_false
  query
  |> string.contains("colours=123456&colours=abcdef&colours=aabbcc")
  |> should.be_true
  let assert Ok(restored) = uri.parse_query(query)
  cool_s.init(restored) |> should.equal(model)
}

pub fn repeated_colour_parameters_test() {
  let model =
    cool_s.init([
      #("colours", "#ABCDEF"),
      #("width", "30"),
      #("colours", "invalid"),
      #("colours", "abcdef"),
      #("colours", ""),
      #("colours", "123456"),
    ])
  model.colours
  |> should.equal(["abcdef", "f5a9b8", "abcdef", "f5a9b8", "123456"])
  model.width |> should.equal(30.0)
  let assert Ok(pairs) =
    model |> cool_s.to_pairs |> uri.query_to_string |> uri.parse_query
  cool_s.init(pairs) |> should.equal(model)

  cool_s.init(list.repeat(#("colours", "123456"), 99)).colours
  |> should.equal(list.repeat("123456", 16))
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
  markup |> string.contains("Flip in / out") |> should.be_false
  markup
  |> string.contains("Swap ribbon 1 with next ribbon")
  |> should.be_true
  markup
  |> string.contains("aria-label=\"Swap ribbon 5 with next ribbon\" disabled")
  |> should.be_true
  let assert [size_controls, colours_and_presets] =
    string.split(markup, "<fieldset class=\"ribbon-controls\">")
  size_controls |> string.contains(">Flip</button>") |> should.be_true
  size_controls |> string.contains("Flag palettes") |> should.be_false
  let assert [colour_controls, presets] =
    string.split(colours_and_presets, "<fieldset class=\"pride-presets\">")
  colour_controls |> string.contains("type=\"color\"") |> should.be_true
  presets |> string.contains("Flag palettes") |> should.be_true
  let single =
    cool_s.init([#("colours", "ffffff")])
    |> cool_s.view
    |> element.to_string
  single
  |> string.contains("aria-label=\"Swap ribbon 1 with next ribbon\" disabled")
  |> should.be_true
  cool_s.preview() |> string.contains("fill=\"#5bcefa\"") |> should.be_true
  cool_s.preview() |> string.contains("NaN") |> should.be_false
}
