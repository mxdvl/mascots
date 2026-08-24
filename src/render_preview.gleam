import gleam/io
import penelopea

/// Run with `gleam run -m render_preview` to print the default pea as an SVG
/// string (e.g. to pipe into a file for visual inspection), without touching
/// the real app's entrypoint in penelopea.gleam.
pub fn main() {
  io.println(penelopea.preview())
}
