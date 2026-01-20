export const $ = (selector, scope = document) => scope.querySelector(selector);
export const $$ = (selector, scope = document) => Array.from(scope.querySelectorAll(selector));

export function on(element, event, handler) {
  if (!element) return;
  element.addEventListener(event, handler);
}
