import { readFile } from "node:fs/promises";

// Never send CI credentials to a workflow input URL.
if (process.env.PANEL_URL !== "https://giera-panel.vercel.app") throw new Error("Unexpected panel origin");
if (!/^[a-f0-9-]{36}$/.test(process.env.DEPLOYMENT_ID || "") ||
    !/^[a-f0-9]{40}$/.test(process.env.COMMIT_SHA || "")) throw new Error("Invalid deployment identity");
let result;
if (process.argv[2] === "running") result = { status: "running", result: "Przygotowanie wybranej wersji serwera." };
else {
  try { result = JSON.parse(await readFile(process.env.RESULT_FILE, "utf8")); }
  catch { result = process.env.REMOTE_MAY_RUN === "true"
    ? { status: "unknown", result: "Utracono potwierdzenie z VPS. Sprawdz log workflow i wynik uslugi przed kolejnym wdrozeniem." }
    : { status: "failed", result: "Przygotowanie wdrozenia nie powiodlo sie. Gra na VPS nie zostala zmieniona." }; }
}
const body = { ...result, deploymentId: process.env.DEPLOYMENT_ID, commit: process.env.COMMIT_SHA,
  runUrl: `${process.env.GITHUB_SERVER_URL}/${process.env.GITHUB_REPOSITORY}/actions/runs/${process.env.GITHUB_RUN_ID}` };
for (let attempt = 0; attempt < 3; attempt++) {
  try {
    const response = await fetch(`${process.env.PANEL_URL}/api/ci/deployments`, {
      method: "POST", headers: { "content-type": "application/json", authorization: `Bearer ${process.env.CI_TOKEN}` },
      body: JSON.stringify(body), signal: AbortSignal.timeout(15000), redirect: "error",
    });
    if (!response.ok) throw new Error(`Panel HTTP ${response.status}`);
    break;
  } catch (error) { if (attempt === 2) throw error; }
}
if (process.argv[2] !== "running" && result.status !== "succeeded") process.exitCode = 1;
