import gleam/io
import mascots/cool_s

/// Run with `gleam run -m render_preview` to print the default Cool S as an
/// SVG string (e.g. to pipe into a file for visual inspection), without
/// touching the real app's entrypoint in mascots.gleam.
pub fn main() {
  io.println(cool_s.preview())
}
