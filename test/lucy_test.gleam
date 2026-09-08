import gleam/list
import gleam/result
import gleam/string
import gleam/uri
import gleeunit/should
import lustre/element
import mascots/cool_s
import mascots/lucy

pub fn defaults_and_legacy_single_colour_urls_test() {
  let defaults = lucy.init([])
  defaults |> should.equal(lucy.Model(count: 7, colours: ["ffaff3"]))
  defaults
  |> lucy.to_pairs
  |> should.equal([#("count", "7"), #("colour", "ffaff3")])

  "count=11&colour=%23ABCDEF"
  |> uri.parse_query
  |> result.unwrap([])
  |> lucy.init
  |> should.equal(lucy.Model(count: 11, colours: ["abcdef"]))

  let markup = defaults |> lucy.view |> element.to_string
  markup |> string.contains("fill=\"#ffaff3\"") |> should.be_true
  markup |> string.contains("fill=\"#1e1e1e\"") |> should.be_true
}

pub fn repeated_and_comma_separated_colours_keep_first_six_test() {
  lucy.init([
    #("colour", ",#ABCDEF,,abcdef"),
    #("count", "9"),
    #("colour", ""),
    #("colour", "invalid,123456,"),
    #("colour", "#AABBCC,000000,ffffff"),
    #("colour", "654321"),
  ])
  |> should.equal(
    lucy.Model(count: 9, colours: [
      "abcdef",
      "abcdef",
      "ffaff3",
      "123456",
      "aabbcc",
      "000000",
    ]),
  )

  list.each(["#abc", "1234567", "gggggg"], fn(colour) {
    lucy.init([#("colour", colour)]).colours |> should.equal(["ffaff3"])
  })
  use pairs <- list.each([
    [#("colour", "")],
    [#("colour", ",,")],
    [#("colour", ""), #("colour", ",")],
  ])
  lucy.init(pairs) |> should.equal(lucy.Model(count: 7, colours: ["ffaff3"]))
}

pub fn live_edited_cool_s_palette_transfers_and_round_trips_test() {
  let edited =
    cool_s.init([
      #("colour", "123456,abcdef,123456,ff0000,00ff00,000000,ffffff"),
    ])
    |> cool_s.update(cool_s.UserChangedColour(1, "#AABBCC"))
  let transferred = edited |> cool_s.to_pairs |> lucy.init
  transferred
  |> should.equal(
    lucy.Model(count: 7, colours: [
      "123456",
      "aabbcc",
      "123456",
      "ff0000",
      "00ff00",
      "000000",
    ]),
  )

  let pairs = lucy.to_pairs(transferred)
  pairs
  |> should.equal([
    #("count", "7"),
    #("colour", "123456"),
    #("colour", "aabbcc"),
    #("colour", "123456"),
    #("colour", "ff0000"),
    #("colour", "00ff00"),
    #("colour", "000000"),
  ])
  let query = uri.query_to_string(pairs)
  query |> string.contains("#") |> should.be_false
  query |> string.contains("%23") |> should.be_false
  query
  |> uri.parse_query
  |> result.unwrap([])
  |> lucy.init
  |> should.equal(transferred)
}

pub fn changing_count_preserves_palette_order_and_repeats_test() {
  let model = lucy.init([#("colour", "123456,abcdef,123456,000000")])
  use count <- list.each([3, 7, 27])
  let updated = lucy.update(model, lucy.UserChangedCount(count))
  updated |> should.equal(lucy.Model(..model, count:))
  updated |> lucy.to_pairs |> lucy.init |> should.equal(updated)
}

pub fn clipped_palette_and_white_face_on_black_centre_render_test() {
  use count <- list.each([3, 7, 27])
  let markup =
    lucy.Model(count:, colours: ["ff0000", "00ff00", "000000"])
    |> lucy.view
    |> element.to_string
  list.each(
    [
      "<clipPath",
      "clip-path=\"url(#",
      "stroke=\"#ff0000\"",
      "stroke=\"#00ff00\"",
      "fill=\"#000000\"",
      "fill=\"#ffffff\"",
      "stroke=\"#ffffff\"",
      "<circle",
    ],
    fn(fragment) { markup |> string.contains(fragment) |> should.be_true },
  )
  markup |> string.contains("NaN") |> should.be_false
  markup |> string.contains("Infinity") |> should.be_false
  markup
  |> string.split("fill=\"#ffffff\"")
  |> list.first
  |> result.unwrap("")
  |> string.contains("clip-path=\"url(#")
  |> should.be_true
}
