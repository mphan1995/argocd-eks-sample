import { $ } from "./dom.js";

export function toast(message, type = "info") {
  const el = $("#toast");
  if (!el) return;
  el.textContent = message;
  el.dataset.type = type;
  el.classList.add("show");
  setTimeout(() => el.classList.remove("show"), 2600);
}
