import { apiGet, apiPost } from "../core/api.js";
import { $, on } from "../core/dom.js";
import { toast } from "../core/toast.js";
import { handleMissingRequired } from "../core/install.js";

function renderStack(services) {
  const statusEl = $("#stack-status");
  if (!statusEl) return;
  statusEl.innerHTML = "";

  Object.entries(services).forEach(([name, info]) => {
    const div = document.createElement("div");
    div.className = "status-item";

    const title = document.createElement("div");
    title.className = "status-title";
    title.textContent = name;

    const badge = document.createElement("span");
    badge.className = `badge ${info.ok ? "ok" : "fail"}`;
    badge.textContent = info.ok ? "UP" : "DOWN";

    const meta = document.createElement("span");
    meta.className = "muted";
    meta.textContent = `:${info.port}`;

    const row = document.createElement("div");
    row.className = "status-row";
    row.appendChild(badge);
    row.appendChild(meta);

    div.appendChild(title);
    div.appendChild(row);
    statusEl.appendChild(div);
  });
}

async function loadStack() {
  const res = await apiGet("/api/stack");
  if (res.ok) {
    renderStack(res.data.services || {});
  }
}

async function startStack() {
  const res = await apiPost("/api/stack/start", {});
  if (res.ok) {
    toast("Đang start stack...");
    setTimeout(loadStack, 1500);
  } else {
    toast("Start stack thất bại", "error");
  }
}

async function stopStack() {
  const res = await apiPost("/api/stack/stop", {});
  if (res.ok) {
    toast("Đang stop stack...");
    setTimeout(loadStack, 1500);
  } else {
    toast("Stop stack thất bại", "error");
  }
}

async function runAll() {
  const res = await apiPost("/api/run", { stage: "all" });
  if (handleMissingRequired(res)) return;
  if (!res.ok) {
    toast(res.data?.error || "Không thể chạy pipeline", "error");
    return;
  }
  if (res.data?.missing_optional?.length) {
    toast("Một số tool bảo mật chưa có, pipeline sẽ dùng fallback.", "warning");
  }
  toast(`Đã bắt đầu run ${res.data.run_id}`);
  window.location.href = `/runs/${res.data.run_id}`;
}

export function initDashboard() {
  loadStack();
  on($("#btn-start"), "click", startStack);
  on($("#btn-stop"), "click", stopStack);
  on($("#btn-run-all"), "click", runAll);
}
