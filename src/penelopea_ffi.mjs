// Reads the current URL's query string (without the leading "?"), so the
// app's settings can be restored from a shared link.
export function get_query() {
  if (typeof window === "undefined") return "";
  return window.location.search.replace(/^\?/, "");
}

// Replaces the URL's query string in place (no new history entry, so the
// back button isn't flooded with one entry per slider tick).
export function set_query(query) {
  if (typeof window === "undefined") return undefined;
  const url = new URL(window.location.href);
  url.search = query;
  window.history.replaceState(null, "", url);
  return undefined;
}
