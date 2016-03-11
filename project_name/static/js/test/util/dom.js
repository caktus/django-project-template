// See:
// * http://jaketrent.com/post/testing-react-with-jsdom/
// * http://reactjsnews.com/testing-in-react/

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
