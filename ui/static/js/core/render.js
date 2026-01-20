import { safeText, stageLabel } from "./utils.js";

export function statusBadge(ok) {
  const span = document.createElement("span");
  span.className = `badge ${ok ? "ok" : "fail"}`;
  span.textContent = ok ? "PASS" : "FAIL";
  return span;
}

export function infoBadge(label, tone = "neutral") {
  const span = document.createElement("span");
  span.className = `chip ${tone}`;
  span.textContent = safeText(label);
  return span;
}

export function stageChips(stages) {
  const wrap = document.createElement("div");
  wrap.className = "chip-row";
  stages.forEach((stage) => {
    wrap.appendChild(infoBadge(stageLabel(stage), "soft"));
  });
  return wrap;
}
