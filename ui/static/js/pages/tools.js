import { apiGet, apiPost } from "../core/api.js";
import { $, on } from "../core/dom.js";
import { toast } from "../core/toast.js";
import { getQueryParams, safeText } from "../core/utils.js";
import { statusBadge, stageChips, infoBadge } from "../core/render.js";

const filterModes = [
  { id: "all", label: "All" },
  { id: "missing", label: "Missing" },
  { id: "required", label: "Required" },
  { id: "optional", label: "Optional" },
  { id: "installable", label: "Installable" },
];

const state = {
  tools: [],
  filter: "all",
  summary: { total: 0, missing_required: 0, missing_optional: 0 },
};

function setInstallOutput(text) {
  const output = $("#install-output");
  if (!output) return;
  output.textContent = text || "";
}

function renderSummary() {
  const summaryEl = $("#tools-summary");
  if (!summaryEl) return;
  summaryEl.innerHTML = "";

  const items = [
    { label: "Total", value: state.summary.total },
    { label: "Missing required", value: state.summary.missing_required },
    { label: "Missing optional", value: state.summary.missing_optional },
  ];

  items.forEach((item) => {
    const box = document.createElement("div");
    box.className = "summary-item";
    const label = document.createElement("div");
    label.className = "summary-label";
    label.textContent = item.label;
    const value = document.createElement("div");
    value.className = "summary-value";
    value.textContent = String(item.value);
    box.appendChild(label);
    box.appendChild(value);
    summaryEl.appendChild(box);
  });
}

function renderMissingCallout() {
  const callout = $("#missing-tools");
  if (!callout) return;
  const params = getQueryParams();
  const missingParam = params.get("missing");

  const missingIds = missingParam ? missingParam.split(",").map((x) => x.trim()) : [];
  const missingTools = missingIds
    .map((id) => state.tools.find((tool) => tool.id === id))
    .filter(Boolean);

  const requiredMissing = state.tools.filter((tool) => tool.critical && !tool.ok);

  if (missingTools.length === 0 && requiredMissing.length === 0) {
    callout.classList.add("hidden");
    callout.textContent = "";
    return;
  }

  callout.classList.remove("hidden");
  callout.classList.add("warn");
  callout.innerHTML = "";

  const title = document.createElement("div");
  title.className = "callout-title";
  title.textContent = "Thiếu tool bắt buộc";

  const list = document.createElement("div");
  list.className = "chip-row";
  (missingTools.length ? missingTools : requiredMissing).forEach((tool) => {
    list.appendChild(infoBadge(tool.name, "warn"));
  });

  const note = document.createElement("p");
  note.className = "muted";
  note.textContent = "Hãy cài đặt các tool này trước khi chạy pipeline full.";

  callout.appendChild(title);
  callout.appendChild(list);
  callout.appendChild(note);
}

function filterTools(tools) {
  switch (state.filter) {
    case "missing":
      return tools.filter((tool) => !tool.ok);
    case "required":
      return tools.filter((tool) => tool.critical);
    case "optional":
      return tools.filter((tool) => !tool.critical);
    case "installable":
      return tools.filter((tool) => tool.installable);
    default:
      return tools;
  }
}

function renderFilters() {
  const container = $("#tool-filters");
  if (!container) return;
  container.innerHTML = "";

  filterModes.forEach((mode) => {
    const chip = document.createElement("button");
    chip.className = `chip ${state.filter === mode.id ? "active" : ""}`;
    chip.type = "button";
    chip.textContent = mode.label;
    chip.addEventListener("click", () => {
      state.filter = mode.id;
      renderFilters();
      renderTable();
    });
    container.appendChild(chip);
  });
}

async function installTool(toolId) {
  setInstallOutput("Đang cài đặt...\n");
  const res = await apiPost("/api/tools/install", { tool_id: toolId });
  if (res.ok && res.data.ok) {
    toast("Cài đặt thành công", "success");
  } else {
    const message = res.data?.output || res.data?.error || "Cài đặt thất bại";
    toast(message, "error");
  }
  setInstallOutput(res.data?.output || "");
  await loadTools();
}

function renderTable() {
  const tbody = $("#tools-table tbody");
  if (!tbody) return;
  tbody.innerHTML = "";

  const toolMap = new Map(state.tools.map((tool) => [tool.id, tool]));
  const rows = filterTools(state.tools);
  rows.forEach((tool) => {
    const tr = document.createElement("tr");

    const nameTd = document.createElement("td");
    const name = document.createElement("div");
    name.className = "tool-name";
    name.textContent = tool.name;
    const titleWrap = document.createElement("div");
    titleWrap.className = "tool-title";
    titleWrap.appendChild(name);
    titleWrap.appendChild(infoBadge(tool.critical ? "core" : "optional", tool.critical ? "soft" : "warn"));
    const binary = document.createElement("div");
    binary.className = "muted small";
    binary.textContent = tool.binary || "";
    nameTd.appendChild(titleWrap);
    nameTd.appendChild(binary);

    const statusTd = document.createElement("td");
    statusTd.appendChild(statusBadge(tool.ok));

    const versionTd = document.createElement("td");
    versionTd.textContent = safeText(tool.version) || "-";

    const recTd = document.createElement("td");
    recTd.textContent = safeText(tool.recommended) || "-";

    const stageTd = document.createElement("td");
    stageTd.appendChild(stageChips(tool.required_for || []));

    const installTd = document.createElement("td");
    const installWrap = document.createElement("div");
    installWrap.className = "install-cell";

    if (tool.ok) {
      installWrap.appendChild(infoBadge("Installed", "soft"));
    } else if (tool.installable) {
      const btn = document.createElement("button");
      btn.className = "btn mini";
      btn.textContent = "Install";
      const missingDeps = (tool.install_requires || []).filter(
        (dep) => !toolMap.get(dep)?.ok
      );
      if (missingDeps.length) {
        btn.disabled = true;
        btn.classList.add("disabled");
      } else {
        btn.addEventListener("click", () => installTool(tool.id));
      }
      installWrap.appendChild(btn);

      if (tool.install_command) {
        const code = document.createElement("code");
        code.textContent = tool.install_command;
        installWrap.appendChild(code);
      }
      if (missingDeps.length) {
        const note = document.createElement("div");
        note.className = "muted small";
        const names = missingDeps.map((dep) => toolMap.get(dep)?.name || dep);
        note.textContent = `Cần: ${names.join(", ")}`;
        installWrap.appendChild(note);
      }
      if (tool.install_note) {
        const note = document.createElement("div");
        note.className = "muted small";
        note.textContent = tool.install_note;
        installWrap.appendChild(note);
      }
    } else {
      installWrap.appendChild(infoBadge("Manual", "warn"));
      if (tool.install_hint) {
        const hint = document.createElement("div");
        hint.className = "muted small";
        hint.textContent = tool.install_hint;
        installWrap.appendChild(hint);
      }
    }

    installTd.appendChild(installWrap);

    tr.appendChild(nameTd);
    tr.appendChild(statusTd);
    tr.appendChild(versionTd);
    tr.appendChild(recTd);
    tr.appendChild(stageTd);
    tr.appendChild(installTd);
    tbody.appendChild(tr);
  });
}

async function loadTools() {
  const res = await apiGet("/api/tools");
  if (!res.ok) {
    toast("Không thể tải tools", "error");
    return;
  }
  state.tools = res.data.tools || [];
  state.summary = res.data.summary || state.summary;
  renderSummary();
  renderMissingCallout();
  renderFilters();
  renderTable();
}

export function initTools() {
  on($("#btn-refresh-tools"), "click", loadTools);
  setInstallOutput("Chưa có log cài đặt.");
  const params = getQueryParams();
  if (params.get("missing")) {
    state.filter = "missing";
  }
  loadTools();
}
