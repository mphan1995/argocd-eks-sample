const $ = (sel) => document.querySelector(sel);
const $$ = (sel) => document.querySelectorAll(sel);

let pollTimer = null;

function toast(message, isError = false) {
  const el = $("#toast");
  if (!el) return;
  el.textContent = message;
  el.style.background = isError ? "#991b1b" : "#111827";
  el.classList.add("show");
  setTimeout(() => el.classList.remove("show"), 2000);
}

function apiHeaders() {
  const headers = { "Content-Type": "application/json" };
  if (window.UI_TOKEN) {
    headers["X-API-Token"] = window.UI_TOKEN;
  }
  return headers;
}

async function apiFetch(path, options = {}) {
  const res = await fetch(path, {
    ...options,
    headers: { ...apiHeaders(), ...(options.headers || {}) },
  });
  if (!res.ok) {
    const text = await res.text();
    throw new Error(text || `HTTP ${res.status}`);
  }
  return res.json();
}

function badge(ok) {
  if (ok === true) return '<span class="badge ok">PASS</span>';
  if (ok === false) return '<span class="badge fail">FAIL</span>';
  return '<span class="badge warn">N/A</span>';
}

function startPolling(fn) {
  if (pollTimer) return;
  pollTimer = setInterval(fn, 2000);
}

function stopPolling() {
  if (pollTimer) {
    clearInterval(pollTimer);
    pollTimer = null;
  }
}

async function loadStack() {
  const data = await apiFetch("/api/stack");
  const statusEl = $("#stack-status");
  if (!statusEl) return;
  statusEl.innerHTML = "";
  Object.entries(data.services).forEach(([name, info]) => {
    const div = document.createElement("div");
    div.className = "status-item";
    div.innerHTML = `<strong>${name}</strong><br>${badge(info.ok)} <span class="muted">:${info.port}</span>`;
    statusEl.appendChild(div);
  });
}

async function loadTools() {
  const data = await apiFetch("/api/tools");
  const tbody = $("#tools-table tbody");
  if (!tbody) return;
  tbody.innerHTML = "";
  data.tools.forEach((tool) => {
    const tr = document.createElement("tr");
    tr.innerHTML = `
      <td>${tool.name}</td>
      <td>${badge(tool.ok)}</td>
      <td class="muted">${tool.version || ""}</td>
    `;
    tbody.appendChild(tr);
  });
}

async function loadRuns() {
  const data = await apiFetch("/api/runs");
  const tbody = $("#runs-table tbody");
  if (!tbody) return;
  tbody.innerHTML = "";

  data.runs.forEach((run) => {
    const tr = document.createElement("tr");
    tr.innerHTML = `
      <td><a href="/runs/${run.run_id}">${run.run_id}</a></td>
      <td>${run.state}</td>
      <td>${run.stage || ""}</td>
      <td class="muted">${run.started_at || ""}</td>
    `;
    tbody.appendChild(tr);
  });

  const running = data.runs.some((r) => r.state === "running");
  if (running) startPolling(loadRuns); else stopPolling();
}

async function loadRunDetail(runId) {
  const data = await apiFetch(`/api/runs/${runId}`);
  const meta = $("#run-meta");
  const logs = $("#run-logs");
  if (!meta || !logs) return;

  meta.innerHTML = `
    <div><strong>State:</strong> ${data.state}</div>
    <div><strong>Stage:</strong> ${data.stage || ""}</div>
    <div><strong>Started:</strong> ${data.started_at || ""}</div>
    <div><strong>Ended:</strong> ${data.ended_at || ""}</div>
  `;

  logs.innerHTML = "";
  Object.entries(data.logs).forEach(([stage, content]) => {
    const card = document.createElement("div");
    card.className = "log-card";
    const h3 = document.createElement("h3");
    const pre = document.createElement("pre");
    h3.textContent = stage;
    pre.textContent = content || "";
    card.appendChild(h3);
    card.appendChild(pre);
    logs.appendChild(card);
  });

  const running = data.state === "running";
  if (running) startPolling(() => loadRunDetail(runId)); else stopPolling();
}

async function startRun(stage) {
  try {
    const res = await apiFetch("/api/run", {
      method: "POST",
      body: JSON.stringify({ stage }),
    });
    toast(`Đã bắt đầu run ${res.run_id}`);
    window.location.href = `/runs/${res.run_id}`;
  } catch (err) {
    toast(`Lỗi: ${err.message}`, true);
  }
}

async function startStack() {
  try {
    await apiFetch("/api/stack/start", { method: "POST" });
    toast("Đang start stack...");
    setTimeout(loadStack, 1500);
  } catch (err) {
    toast(`Lỗi: ${err.message}`, true);
  }
}

async function stopStack() {
  try {
    await apiFetch("/api/stack/stop", { method: "POST" });
    toast("Đang stop stack...");
    setTimeout(loadStack, 1500);
  } catch (err) {
    toast(`Lỗi: ${err.message}`, true);
  }
}

document.addEventListener("DOMContentLoaded", () => {
  const page = document.body.dataset.page;

  if (page === "dashboard") {
    loadStack();
    $("#btn-start")?.addEventListener("click", startStack);
    $("#btn-stop")?.addEventListener("click", stopStack);
    $("#btn-run-all")?.addEventListener("click", () => startRun("all"));
  }

  if (page === "tools") {
    loadTools();
    $("#btn-refresh-tools")?.addEventListener("click", loadTools);
  }

  if (page === "runs") {
    loadRuns();
    $("#btn-run")?.addEventListener("click", () => {
      const stage = $("#stage-select").value;
      startRun(stage);
    });
  }

  if (page === "run-detail") {
    const runId = document.body.dataset.runId;
    if (runId) {
      $("#download-link").setAttribute("href", `/api/runs/${runId}/download`);
      loadRunDetail(runId);
    }
  }
});
