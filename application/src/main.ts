import express from "express";

export const app = express();

const port = Number(process.env.PORT || 8080);

app.get("/healthz", (_req, res) => {
  res.status(200).json({ status: "ok" });
});

app.get("/readyz", (_req, res) => {
  res.status(200).json({ status: "ready" });
});

app.get("/", (_req, res) => {
  res.status(200).json({ service: "cloudnative-app", version: process.env.APP_VERSION || "dev" });
});

if (require.main === module) {
  app.listen(port, () => {
    // Keep logs structured for centralized log pipelines.
    console.log(JSON.stringify({ level: "info", message: "server_started", port }));
  });
}
