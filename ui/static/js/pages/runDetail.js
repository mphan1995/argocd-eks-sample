import { apiGet, apiPost } from "../core/api.js";
import { $, on } from "../core/dom.js";
import { startPolling, stopPolling } from "../core/poll.js";
import { toast } from "../core/toast.js";

function renderMeta(data) {
  const meta = $("#run-meta");
  if (!meta) return;
  meta.innerHTML = "";
  const deleteBtn = $("#btn-delete-run");
  if (deleteBtn) {
    deleteBtn.disabled = data.state === "running";
    deleteBtn.classList.toggle("disabled", data.state === "running");
  }
  const fields = [
    { label: "State", value: data.state },
    { label: "Stage", value: data.stage },
    { label: "Started", value: data.started_at },
    { label: "Ended", value: data.ended_at },
  ];
  fields.forEach((item) => {
    const row = document.createElement("div");
    row.className = "meta-row";
    const label = document.createElement("div");
    label.className = "meta-label";
    label.textContent = item.label;
    const value = document.createElement("div");
    value.className = "meta-value";
    value.textContent = item.value || "";
    row.appendChild(label);
    row.appendChild(value);
    meta.appendChild(row);
  });
}

function renderLogs(logs) {
  const wrap = $("#run-logs");
  if (!wrap) return;
  wrap.innerHTML = "";

  Object.entries(logs || {}).forEach(([stage, content]) => {
    const card = document.createElement("div");
    card.className = "log-card";

    const header = document.createElement("div");
    header.className = "log-head";

    const title = document.createElement("h3");
    title.textContent = stage;

    header.appendChild(title);

    const pre = document.createElement("pre");
    pre.textContent = content || "";

    card.appendChild(header);
    card.appendChild(pre);
    wrap.appendChild(card);
  });
}

async function loadRun(runId) {
  const res = await apiGet(`/api/runs/${runId}`);
  if (!res.ok) {
    toast("Không thể tải run", "error");
    return;
  }

  renderMeta(res.data);
  renderLogs(res.data.logs || {});

  const running = res.data.state === "running";
  if (running) startPolling(() => loadRun(runId)); else stopPolling();
}

export function initRunDetail() {
  const runId = document.body.dataset.runId;
  if (!runId) return;
  const link = $("#download-link");
  if (link) link.setAttribute("href", `/api/runs/${runId}/download`);
  const deleteBtn = $("#btn-delete-run");
  on(deleteBtn, "click", async () => {
    if (!window.confirm(`Xóa run ${runId}?`)) return;
    const res = await apiPost(`/api/runs/${runId}/delete`, {});
    if (!res.ok) {
      toast(res.data?.error || "Xóa run thất bại", "error");
      return;
    }
    toast(`Đã xóa run ${runId}`, "success");
    window.location.href = "/runs";
  });
  loadRun(runId);
}
