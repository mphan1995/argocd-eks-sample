const defaultHeaders = { "Content-Type": "application/json" };

function tokenHeaders() {
  const headers = { ...defaultHeaders };
  if (window.UI_TOKEN) {
    headers["X-API-Token"] = window.UI_TOKEN;
  }
  return headers;
}

export async function apiRequest(path, options = {}) {
  try {
    const res = await fetch(path, {
      ...options,
      headers: { ...tokenHeaders(), ...(options.headers || {}) },
    });

    let data = null;
    try {
      data = await res.json();
    } catch (_) {
      data = null;
    }

    return { ok: res.ok, status: res.status, data };
  } catch (error) {
    return { ok: false, status: 0, data: { error: String(error) } };
  }
}

export function apiGet(path) {
  return apiRequest(path, { method: "GET" });
}

export function apiPost(path, body) {
  return apiRequest(path, {
    method: "POST",
    body: JSON.stringify(body || {}),
  });
}
