import { Ok, Error } from "./gleam.mjs";

/**
 * Reads the current URL's query string (without the leading "?")
 * @returns {string}
 */
export function get_query() {
  try {
    return window.location.search.replace(/^\?/, "");
  } catch (error) {
    console.error(error);
    return "";
  }
}

// How often the URL is actually allowed to be replaced, so dragging a
// slider doesn't hammer `history.replaceState` on every single tick.
const THROTTLE_MS = 240;

let last_run = 0;
let scheduled = null;

function replace_query(query) {
  try {
    const url = new URL(window.location.href);
    url.search = query;
    window.history.replaceState(null, "", url);
  } catch (error) {
    console.error(error);
  }
  last_run = Date.now();
  scheduled = null;
}

/**
 * Replaces the URL's query string in place, throttled so that frequent
 * calls (e.g. from dragging a slider) only actually touch the URL at most
 * once per `THROTTLE_MS`. The most recent query always wins, and is
 * guaranteed to be applied eventually via the trailing call.
 * @param {string} query
 * @returns {void}
 */
export function set_query(query) {
  if (scheduled != null) clearTimeout(scheduled);

  const elapsed = Date.now() - last_run;
  if (elapsed >= THROTTLE_MS) {
    replace_query(query);
  } else {
    scheduled = setTimeout(() => replace_query(query), THROTTLE_MS - elapsed);
  }
}

// TODO: use community maths

export function sin(theta) {
  return Math.sin(theta);
}

export function cos(theta) {
  return Math.cos(theta);
}

export function atan2(y, x) {
  return Math.atan2(y, x);
}
