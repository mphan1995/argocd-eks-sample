let pollTimer = null;

export function startPolling(fn, interval = 2000) {
  if (pollTimer) return;
  pollTimer = setInterval(fn, interval);
}

export function stopPolling() {
  if (pollTimer) {
    clearInterval(pollTimer);
    pollTimer = null;
  }
}
