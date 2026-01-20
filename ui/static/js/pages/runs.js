import { apiGet, apiPost } from "../core/api.js";
import { $, on } from "../core/dom.js";
import { toast } from "../core/toast.js";
import { startPolling, stopPolling } from "../core/poll.js";
import { redirectToTools } from "../core/install.js";

async function deleteRun(runId) {
  if (!window.confirm(`Xóa run ${runId}?`)) return;
  const res = await apiPost(`/api/runs/${runId}/delete`, {});
  if (!res.ok) {
    toast(res.data?.error || "Xóa run thất bại", "error");
    return;
  }
  toast(`Đã xóa run ${runId}`, "success");
  loadRuns();
}

function renderRuns(runs) {
  const tbody = $("#runs-table tbody");
  if (!tbody) return;
  tbody.innerHTML = "";

  runs.forEach((run) => {
    const tr = document.createElement("tr");

    const idTd = document.createElement("td");
    const link = document.createElement("a");
    link.href = `/runs/${run.run_id}`;
    link.textContent = run.run_id;
    idTd.appendChild(link);

    const stateTd = document.createElement("td");
    stateTd.textContent = run.state || "";

    const stageTd = document.createElement("td");
    stageTd.textContent = run.stage || "";

    const timeTd = document.createElement("td");
    timeTd.className = "muted";
    timeTd.textContent = run.started_at || "";

    const actionTd = document.createElement("td");
    const delBtn = document.createElement("button");
    delBtn.className = "btn danger mini";
    delBtn.textContent = "Delete";
    if (run.state === "running") {
      delBtn.disabled = true;
      delBtn.classList.add("disabled");
    } else {
      delBtn.addEventListener("click", () => deleteRun(run.run_id));
    }
    actionTd.appendChild(delBtn);

    tr.appendChild(idTd);
    tr.appendChild(stateTd);
    tr.appendChild(stageTd);
    tr.appendChild(timeTd);
    tr.appendChild(actionTd);
    tbody.appendChild(tr);
  });
}

function showWarning(missing) {
  const warn = $("#run-warning");
  if (!warn) return;
  warn.innerHTML = "";
  warn.classList.remove("hidden");

  const title = document.createElement("div");
  title.className = "callout-title";
  title.textContent = "Thiếu tool bắt buộc";

  const list = document.createElement("div");
  list.className = "chip-row";
  missing.forEach((tool) => {
    const chip = document.createElement("span");
    chip.className = "chip warn";
    chip.textContent = tool.name;
    list.appendChild(chip);
  });

  const action = document.createElement("button");
  action.className = "btn ghost";
  action.textContent = "Mở Tools";
  action.addEventListener("click", () => redirectToTools(missing));

  warn.appendChild(title);
  warn.appendChild(list);
  warn.appendChild(action);
}

function clearWarning() {
  const warn = $("#run-warning");
  if (!warn) return;
  warn.classList.add("hidden");
  warn.textContent = "";
}

async function loadRuns() {
  const res = await apiGet("/api/runs");
  if (!res.ok) {
    toast("Không thể tải runs", "error");
    return;
  }

  const runs = res.data.runs || [];
  renderRuns(runs);

  const running = runs.some((r) => r.state === "running");
  if (running) startPolling(loadRuns); else stopPolling();
}

async function startRun(stage) {
  clearWarning();
  const res = await apiPost("/api/run", { stage });
  if (res.status === 422) {
    showWarning(res.data?.missing?.required || []);
    toast(res.data?.message || "Thiếu tool bắt buộc", "error");
    return;
  }
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

export function initRuns() {
  on($("#btn-run"), "click", () => {
    const select = $("#stage-select");
    const stage = select ? select.value : "all";
    startRun(stage);
  });
  loadRuns();
}
