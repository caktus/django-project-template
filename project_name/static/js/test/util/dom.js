/**
 * @module dom.js
 *
 * This script sets up the `document` global value to be a jsdom dummy DOM.
 * This makes it possible to test DOM interactions without a browser.
 * It must be imported by Mocha before running DOM-dependent tests.
 * This module is imported for its side effects and does not export any values.
 *
 * For more info, see:
 * http://jaketrent.com/post/testing-react-with-jsdom/
 * http://reactjsnews.com/testing-in-react/
 */

import { jsdom } from 'node-jsdom';

var doc = jsdom('<!doctype html><html><body></body></html>');
var win = doc.defaultView;

global.document = doc;
global.window = win;

for (let key in win) {
  if (!win.hasOwnProperty(key)) { continue; }

  if (key in global) { continue; }

  global[key] = win[key];
}
