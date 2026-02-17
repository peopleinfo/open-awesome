import { readFile } from "node:fs/promises";
import { fileURLToPath } from "node:url";
import express from "express";
import {
  createTodo,
  deleteTodo,
  listTodos,
  updateTodo,
} from "./store.js";
import {
  asSettingsSummary,
  readSettings,
  writeSettings,
} from "./settings.js";
import { handleTelegramUpdate, sendTelegramMessage } from "./telegram.js";
import {
  applyCodexDefaults,
  getInstallJobStatus,
  getGatewayState,
  readGatewayLogs,
  runAgentPrompt,
  runChannelsDoctor,
  runDoctor,
  startInstallZeroClawJob,
  startGateway,
  statusSummary,
  stopGateway,
  zeroClawConfigStatus,
  zeroClawInstallationStatus,
} from "./zeroclaw.js";

const ENV_PATH = new URL("../../../.env", import.meta.url);

async function loadEnvFile() {
  try {
    const filePath = fileURLToPath(ENV_PATH);
    const raw = await readFile(filePath, "utf8");
    for (const line of raw.split(/\r?\n/)) {
      const trimmed = line.trim();
      if (!trimmed || trimmed.startsWith("#")) {
        continue;
      }
      const equalIndex = trimmed.indexOf("=");
      if (equalIndex <= 0) {
        continue;
      }
      const key = trimmed.slice(0, equalIndex).trim();
      const value = trimmed.slice(equalIndex + 1).trim();
      if (!(key in process.env)) {
        process.env[key] = value;
      }
    }
  } catch (error) {
    if (!error || error.code !== "ENOENT") {
      throw error;
    }
  }
}

function toPositiveInt(value, fallback) {
  const parsed = Number(value);
  if (!Number.isInteger(parsed) || parsed <= 0) {
    return fallback;
  }
  return parsed;
}

await loadEnvFile();

const host = process.env.ZERO_CLAW_API_HOST || "127.0.0.1";
const port = toPositiveInt(process.env.ZERO_CLAW_API_PORT, 3010);
const envTelegramSecret = process.env.TELEGRAM_WEBHOOK_SECRET || "";
const envTelegramBotToken = process.env.TELEGRAM_BOT_TOKEN || "";

async function getSetupReadiness() {
  const settings = await readSettings();
  const install = await zeroClawInstallationStatus();
  const defaults = await zeroClawConfigStatus();
  const hasBotToken = Boolean(settings.telegram.botToken || envTelegramBotToken);
  const hasWebhookUrl = Boolean(settings.telegram.webhookUrl);
  const ready = Boolean(
    settings.setupCompleted && install.installed && hasBotToken,
  );

  return {
    ready,
    checks: {
      setupCompleted: settings.setupCompleted,
      zeroclawInstalled: install.installed,
      hasTelegramBotToken: hasBotToken,
      hasTelegramWebhookUrl: hasWebhookUrl,
      codexDefaultsConfigured: Boolean(defaults.codexDefaults),
    },
    settings: asSettingsSummary(settings),
    zeroclaw: install,
    defaults,
  };
}

async function requireWorkspaceReady(res) {
  const readiness = await getSetupReadiness();
  if (!readiness.ready) {
    res.status(403).json({
      ok: false,
      error: "Setup is required before using this section.",
      readiness,
    });
    return null;
  }
  return readiness;
}

const app = express();
app.use(express.json({ limit: "1mb" }));

app.use((req, res, next) => {
  res.setHeader("access-control-allow-origin", "*");
  res.setHeader("access-control-allow-methods", "GET,POST,PUT,DELETE,OPTIONS");
  res.setHeader("access-control-allow-headers", "content-type,x-telegram-bot-api-secret-token");
  if (req.method === "OPTIONS") {
    res.status(204).end();
    return;
  }
  next();
});

app.get("/health", async (_req, res) => {
  const todos = await listTodos();
  const readiness = await getSetupReadiness();
  const gateway = getGatewayState();
  res.json({
    ok: true,
    host,
    port,
    todoCount: todos.length,
    setupCompleted: readiness.checks.setupCompleted,
    setupReady: readiness.ready,
    zeroclawInstalled: readiness.checks.zeroclawInstalled,
    zeroclawGatewayRunning: gateway.running,
    now: new Date().toISOString(),
  });
});

app.get("/api/setup/readiness", async (_req, res) => {
  const readiness = await getSetupReadiness();
  res.json({
    ok: true,
    readiness,
  });
});

app.get("/api/zeroclaw/status", async (_req, res) => {
  const status = await statusSummary();
  res.json({
    ok: true,
    ...status,
  });
});

app.get("/api/zeroclaw/defaults", async (_req, res) => {
  const defaults = await zeroClawConfigStatus();
  res.json({
    ok: true,
    defaults,
  });
});

app.post("/api/zeroclaw/defaults/codex", async (_req, res) => {
  const result = await applyCodexDefaults();
  if (!result.ok) {
    res.status(400).json(result);
    return;
  }
  res.json(result);
});

app.post("/api/zeroclaw/gateway/start", async (req, res) => {
  const bind =
    typeof req.body?.bind === "string" && req.body.bind.trim()
      ? req.body.bind.trim()
      : "127.0.0.1";
  const rawPort = Number(req.body?.port);
  const safePort = Number.isInteger(rawPort) && rawPort > 0 ? rawPort : 8080;

  const result = await startGateway(bind, safePort);
  if (!result.ok) {
    res.status(400).json(result);
    return;
  }
  res.json(result);
});

app.post("/api/zeroclaw/gateway/stop", async (_req, res) => {
  const result = await stopGateway();
  res.json(result);
});

app.get("/api/zeroclaw/gateway/logs", async (req, res) => {
  const tail = Number(req.query?.tail);
  const logs = await readGatewayLogs(tail);
  if (!logs.ok) {
    res.status(500).json(logs);
    return;
  }
  res.json(logs);
});

app.post("/api/zeroclaw/doctor", async (_req, res) => {
  const result = await runDoctor();
  if (!result.ok) {
    res.status(400).json(result);
    return;
  }
  res.json(result);
});

app.post("/api/zeroclaw/channels-doctor", async (_req, res) => {
  const result = await runChannelsDoctor();
  if (!result.ok) {
    res.status(400).json(result);
    return;
  }
  res.json(result);
});

app.post("/api/zeroclaw/install", async (_req, res) => {
  const result = startInstallZeroClawJob();
  res.status(result.started ? 202 : 200).json(result);
});

app.get("/api/zeroclaw/install/status", async (_req, res) => {
  res.json({
    ok: true,
    job: getInstallJobStatus(),
  });
});

app.post("/api/zeroclaw/agent/prompt", async (req, res) => {
  const message = String(req.body?.message ?? "").trim();
  if (!message) {
    res.status(400).json({ ok: false, error: "message is required" });
    return;
  }

  const result = await runAgentPrompt(message);
  if (!result.ok) {
    const errorText = String(result.stderr || result.stdout || "").trim();
    res.status(400).json({
      ...result,
      error: errorText || "zeroclaw agent prompt failed.",
    });
    return;
  }
  res.json(result);
});

app.get("/api/settings", async (_req, res) => {
  const settings = await readSettings();
  res.json({
    ok: true,
    settings: asSettingsSummary(settings),
  });
});

app.put("/api/settings", async (req, res) => {
  const payload = req.body ?? {};
  const patch = {};

  if (typeof payload.appName === "string") {
    const appName = payload.appName.trim();
    if (!appName) {
      res.status(400).json({ ok: false, error: "appName cannot be empty" });
      return;
    }
    patch.appName = appName;
  }

  if (typeof payload.setupCompleted === "boolean") {
    if (payload.setupCompleted) {
      res.status(400).json({
        ok: false,
        error:
          "setupCompleted cannot be set directly. Use /api/settings/complete-setup after required checks.",
      });
      return;
    }
    patch.setupCompleted = false;
  }

  if (payload.telegram && typeof payload.telegram === "object") {
    patch.telegram = {};
    if (typeof payload.telegram.botToken === "string") {
      const botToken = payload.telegram.botToken.trim();
      if (botToken) {
        patch.telegram.botToken = botToken;
      }
    }
    if (typeof payload.telegram.webhookUrl === "string") {
      patch.telegram.webhookUrl = payload.telegram.webhookUrl.trim();
    }
    if (typeof payload.telegram.webhookSecret === "string") {
      patch.telegram.webhookSecret = payload.telegram.webhookSecret.trim();
    }
  }

  if (payload.modules && typeof payload.modules === "object") {
    patch.modules = {};
    if (typeof payload.modules.todo === "boolean") {
      patch.modules.todo = payload.modules.todo;
    }
    if (typeof payload.modules.notes === "boolean") {
      patch.modules.notes = payload.modules.notes;
    }
    if (typeof payload.modules.automations === "boolean") {
      patch.modules.automations = payload.modules.automations;
    }
  }

  const settings = await writeSettings(patch);
  res.json({
    ok: true,
    settings: asSettingsSummary(settings),
  });
});

app.post("/api/settings/complete-setup", async (_req, res) => {
  const readiness = await getSetupReadiness();
  if (!readiness.checks.zeroclawInstalled) {
    res.status(400).json({
      ok: false,
      error: "ZeroClaw CLI is not installed. Install it first.",
      readiness,
    });
    return;
  }
  if (!readiness.checks.hasTelegramBotToken) {
    res.status(400).json({
      ok: false,
      error: "Telegram bot token is missing.",
      readiness,
    });
    return;
  }

  const codexDefaults = await applyCodexDefaults();
  const settings = await writeSettings({ setupCompleted: true });
  const nextReadiness = await getSetupReadiness();
  res.json({
    ok: true,
    settings: asSettingsSummary(settings),
    readiness: nextReadiness,
    codexDefaults,
  });
});

app.post("/api/settings/telegram/probe", async (req, res) => {
  const bodyToken =
    typeof req.body?.botToken === "string" ? req.body.botToken.trim() : "";
  const settings = await readSettings();
  const token = bodyToken || settings.telegram.botToken || envTelegramBotToken;

  if (!token) {
    res.status(400).json({ ok: false, error: "Telegram bot token is missing." });
    return;
  }

  try {
    const response = await fetch(`https://api.telegram.org/bot${token}/getMe`);
    const payload = await response.json();
    if (!response.ok || !payload?.ok) {
      res.status(400).json({
        ok: false,
        error: payload?.description || "Telegram token probe failed.",
      });
      return;
    }

    res.json({
      ok: true,
      bot: payload.result,
    });
  } catch (error) {
    res.status(500).json({ ok: false, error: String(error?.message || error) });
  }
});

app.post("/api/settings/telegram/set-webhook", async (req, res) => {
  const settings = await readSettings();
  const webhookUrl =
    typeof req.body?.webhookUrl === "string"
      ? req.body.webhookUrl.trim()
      : settings.telegram.webhookUrl;
  const secretToken =
    typeof req.body?.webhookSecret === "string"
      ? req.body.webhookSecret.trim()
      : settings.telegram.webhookSecret || envTelegramSecret;
  const botToken =
    typeof req.body?.botToken === "string" && req.body.botToken.trim()
      ? req.body.botToken.trim()
      : settings.telegram.botToken || envTelegramBotToken;

  if (!botToken) {
    res.status(400).json({ ok: false, error: "Telegram bot token is missing." });
    return;
  }
  if (!webhookUrl) {
    res.status(400).json({ ok: false, error: "Webhook URL is required." });
    return;
  }

  try {
    const response = await fetch(`https://api.telegram.org/bot${botToken}/setWebhook`, {
      method: "POST",
      headers: { "content-type": "application/json" },
      body: JSON.stringify({
        url: webhookUrl,
        secret_token: secretToken || undefined,
      }),
    });
    const payload = await response.json();
    if (!response.ok || !payload?.ok) {
      res.status(400).json({
        ok: false,
        error: payload?.description || "setWebhook failed",
      });
      return;
    }

    const next = await writeSettings({
      telegram: {
        botToken,
        webhookUrl,
        webhookSecret: secretToken,
      },
    });

    res.json({
      ok: true,
      result: payload.result,
      description: payload.description,
      settings: asSettingsSummary(next),
    });
  } catch (error) {
    res.status(500).json({ ok: false, error: String(error?.message || error) });
  }
});

app.get("/api/todos", async (_req, res) => {
  const readiness = await requireWorkspaceReady(res);
  if (!readiness) {
    return;
  }
  const todos = await listTodos();
  res.json({ ok: true, todos });
});

app.post("/api/todos", async (req, res) => {
  const readiness = await requireWorkspaceReady(res);
  if (!readiness) {
    return;
  }
  const title = String(req.body?.title ?? "").trim();
  if (!title) {
    res.status(400).json({ ok: false, error: "title is required" });
    return;
  }

  const todo = await createTodo(title, "dashboard");
  res.status(201).json({ ok: true, todo });
});

app.put("/api/todos/:id", async (req, res) => {
  const readiness = await requireWorkspaceReady(res);
  if (!readiness) {
    return;
  }
  const id = Number(req.params.id);
  if (!Number.isInteger(id) || id <= 0) {
    res.status(400).json({ ok: false, error: "invalid id" });
    return;
  }

  const patch = {};
  if (typeof req.body?.title === "string") {
    const title = req.body.title.trim();
    if (!title) {
      res.status(400).json({ ok: false, error: "title cannot be empty" });
      return;
    }
    patch.title = title;
  }
  if (typeof req.body?.done === "boolean") {
    patch.done = req.body.done;
  }

  if (Object.keys(patch).length === 0) {
    res.status(400).json({ ok: false, error: "no valid fields to update" });
    return;
  }

  const todo = await updateTodo(id, patch, "dashboard");
  if (!todo) {
    res.status(404).json({ ok: false, error: "todo not found" });
    return;
  }

  res.json({ ok: true, todo });
});

app.delete("/api/todos/:id", async (req, res) => {
  const readiness = await requireWorkspaceReady(res);
  if (!readiness) {
    return;
  }
  const id = Number(req.params.id);
  if (!Number.isInteger(id) || id <= 0) {
    res.status(400).json({ ok: false, error: "invalid id" });
    return;
  }

  const deleted = await deleteTodo(id);
  if (!deleted) {
    res.status(404).json({ ok: false, error: "todo not found" });
    return;
  }

  res.json({ ok: true });
});

app.post("/api/telegram/webhook", async (req, res) => {
  try {
    const settings = await readSettings();
    const telegramSecret = settings.telegram.webhookSecret || envTelegramSecret;
    const telegramBotToken = settings.telegram.botToken || envTelegramBotToken;
    const headerSecret = req.header("x-telegram-bot-api-secret-token") || "";
    if (telegramSecret && headerSecret !== telegramSecret) {
      res.status(401).json({ ok: false, error: "invalid webhook secret token" });
      return;
    }

    const result = await handleTelegramUpdate(req.body, {
      listTodos,
      createTodo,
      updateTodo,
      deleteTodo,
    });

    if (result.handled && result.chatId) {
      await sendTelegramMessage(telegramBotToken, result.chatId, result.text);
    }

    res.json({
      ok: true,
      handled: result.handled,
    });
  } catch (error) {
    res.status(500).json({ ok: false, error: String(error?.message || error) });
  }
});

app.get("/api/telegram/help", async (_req, res) => {
  const settings = await readSettings();
  const requiresSecretHeader = Boolean(
    settings.telegram.webhookSecret || envTelegramSecret,
  );
  res.json({
    ok: true,
    commands: [
      "/todo list",
      "/todo add <title>",
      "/todo done <id>",
      "/todo reopen <id>",
      "/todo delete <id>",
      "/todo help",
    ],
    webhook: "/api/telegram/webhook",
    requiresSecretHeader,
  });
});

app.listen(port, host, () => {
  const webhookMode = envTelegramBotToken ? "enabled" : "disabled";
  console.log(`[zero-claw-api] listening on http://${host}:${port}`);
  console.log(`[zero-claw-api] telegram replies from .env: ${webhookMode}`);
});
