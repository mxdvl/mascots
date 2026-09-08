//// Generate a standalone gallery with `gleam run -m preview_lucy`.
//// Redirect stdout to an HTML file and open it in a browser; no server needed.
//// The first row is the PR screenshot, with additional contrast checks below.

import gleam/int
import gleam/io
import gleam/list
import gleam/result
import gleam/string
import lustre/element
import mascots/cool_s
import mascots/lucy
import mascots/pride

fn svg_only(markup: String) -> String {
  let first =
    markup |> string.split("</svg>") |> list.first |> result.unwrap("")
  first <> "</svg>"
}

fn sample(name: String, count: Int, identifier: String) -> String {
  let colours =
    list.key_find(pride.presets, name) |> result.unwrap(lucy.init([]).colours)
  let pairs = list.map(colours, fn(colour) { #("colour", colour) })
  let model =
    pairs
    |> cool_s.init
    |> cool_s.to_pairs
    |> lucy.init
    |> lucy.update(lucy.UserChangedCount(count))
  let preview =
    model
    |> lucy.view
    |> element.to_string
    |> svg_only
    // Each sample needs its own SVG IDs and matching clip references.
    |> string.replace(lucy.id, lucy.id <> "_" <> identifier)
  "<section><h2>Lucy <span>"
  <> int.to_string(count)
  <> " points</span></h2>"
  <> preview
  <> "<p>"
  <> name
  <> " palette · wider contour ribbons</p></section>"
}

pub fn main() {
  let source_svg =
    cool_s.init([]) |> cool_s.view |> element.to_string |> svg_only
  let examples =
    [5, 7, 11]
    |> list.map(fn(count) { sample("Trans", count, int.to_string(count)) })
    |> string.join("")
  let checks =
    [#("Rainbow", 7), #("Non-binary", 7), #("Bi", 3), #("Classic", 7)]
    |> list.index_map(fn(pair, index) {
      sample(pair.0, pair.1, "check_" <> int.to_string(index))
    })
    |> string.join("")
  let flag =
    pride.trans
    |> list.map(fn(colour) { "<i style=\"background:#" <> colour <> "\"></i>" })
    |> string.join("")
  io.println(
    "<!doctype html><html lang=\"en\"><head><meta charset=\"utf-8\"><title>Trans ribbons on Lucy</title><style>*{box-sizing:border-box}body{margin:0;padding:36px;background:#f1eee9;color:#242424;font:16px system-ui,-apple-system,sans-serif}header{display:flex;align-items:center;gap:22px;margin-bottom:30px}.flag{display:flex;flex-direction:column;width:100px;height:64px;border-radius:5px;overflow:hidden;box-shadow:0 0 0 1px #0001}.flag i{flex:1}h1{margin:0 0 6px;font-size:34px;letter-spacing:-1px}header p{margin:0;color:#62605d}main,.checks{display:grid;grid-template-columns:repeat(4,minmax(0,1fr));gap:20px}section{padding:22px 16px 16px;border-radius:18px;border:1px solid #0001;background:#fffbe8}section.source{background:#e8e4df}h2{font-size:19px;margin:0 0 8px}h2 span{float:right;font-size:13px;font-weight:500;color:#666;line-height:26px}svg{display:block;width:100%;height:330px}section p{margin:12px 0 0;font-size:12px;color:#68645f;text-align:center}footer{margin-top:22px;font-size:12px;color:#706b65;display:flex;justify-content:space-between}.checks{margin-top:40px}</style></head><body><header><div class=\"flag\">"
    <> flag
    <> "</div><div><h1>Trans ribbons, meet Lucy</h1><p>Carry the Cool S palette across mascots — up to six colours, from outline to centre.</p></div></header><main><section class=\"source\"><h2>Cool S <span>Source palette</span></h2>"
    <> source_svg
    <> "<p>Blue · pink · white · pink · blue</p></section>"
    <> examples
    <> "</main><footer><span>Rendered from this branch’s SVG components · trans pride preset</span><span>Lucy © 2026 Louis Pilfold</span></footer><div class=\"checks\">"
    <> checks
    <> "</div></body></html>",
  )
}
