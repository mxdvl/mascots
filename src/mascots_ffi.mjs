/** Reads the current URL's query string (without the leading "?") */
export function get_query() {
  return window.location.search.replace(/^\?/, "");
}

/** Replaces the URL's query string in place */
export function set_query(query) {
  const url = new URL(window.location.href);
  url.search = query;
  window.history.replaceState(null, "", url);
}

// Gleam's stdlib doesn't expose trigonometry, so `lucy.gleam` reaches
// straight for `Math` to convert between Cartesian and polar coordinates.
export function sin(theta) {
  return Math.sin(theta);
}

export function cos(theta) {
  return Math.cos(theta);
}

export function atan2(y, x) {
  return Math.atan2(y, x);
}
