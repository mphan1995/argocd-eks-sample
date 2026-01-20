import { initDashboard } from "./js/pages/dashboard.js";
import { initTools } from "./js/pages/tools.js";
import { initRuns } from "./js/pages/runs.js";
import { initRunDetail } from "./js/pages/runDetail.js";

const page = document.body.dataset.page;

document.addEventListener("DOMContentLoaded", () => {
  switch (page) {
    case "dashboard":
      initDashboard();
      break;
    case "tools":
      initTools();
      break;
    case "runs":
      initRuns();
      break;
    case "run-detail":
      initRunDetail();
      break;
    default:
      break;
  }
});
