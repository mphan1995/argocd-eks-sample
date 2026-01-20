export function getQueryParams() {
  return new URLSearchParams(window.location.search);
}

export function stageLabel(stage) {
  return stage.replace(/_/g, " ");
}

export function safeText(value) {
  return value == null ? "" : String(value);
}
