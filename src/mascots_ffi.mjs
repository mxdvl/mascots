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

/**
 * Replaces the URL's query string in place
 * @param {string} query
 * @returns {void}
 */
export function set_query(query) {
  try {
    const url = new URL(window.location.href);
    url.search = query;
    window.history.replaceState(null, "", url);
    url.href;
  } catch (error) {
    console.error(error);
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
