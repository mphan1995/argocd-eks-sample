import { toast } from "./toast.js";

export function missingToolsMessage(missing) {
  const names = missing.map((tool) => tool.name).join(", ");
  return names || "Thiếu tool bắt buộc.";
}

export function redirectToTools(missing) {
  const ids = missing.map((tool) => tool.id).join(",");
  const url = ids ? `/tools?missing=${encodeURIComponent(ids)}` : "/tools";
  window.location.href = url;
}

export function handleMissingRequired(response) {
  if (response.status !== 422 || !response.data?.missing?.required) {
    return false;
  }
  toast("Thiếu tool bắt buộc. Chuyển sang Tools để cài đặt.", "error");
  redirectToTools(response.data.missing.required);
  return true;
}
