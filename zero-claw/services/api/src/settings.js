import { mkdir, readFile, writeFile } from "node:fs/promises";
import { dirname } from "node:path";
import { fileURLToPath } from "node:url";

const SETTINGS_PATH = new URL("../../../data/settings.json", import.meta.url);
const SETTINGS_FILE = fileURLToPath(SETTINGS_PATH);

function buildDefaultSettings() {
  return {
    appName: "Zero Claw",
    setupCompleted: false,
    telegram: {
      botToken: "",
      webhookUrl: "",
      webhookSecret: "",
    },
    modules: {
      todo: true,
      notes: false,
      automations: false,
    },
    updatedAt: new Date().toISOString(),
  };
}

function pickBoolean(value, fallback) {
  return typeof value === "boolean" ? value : fallback;
}

function normalizeSettings(input) {
  const defaults = buildDefaultSettings();
  const telegramInput = input?.telegram ?? {};
  const modulesInput = input?.modules ?? {};
  return {
    appName:
      typeof input?.appName === "string" && input.appName.trim()
        ? input.appName.trim()
        : defaults.appName,
    setupCompleted: Boolean(input?.setupCompleted),
    telegram: {
      botToken:
        typeof telegramInput.botToken === "string"
          ? telegramInput.botToken.trim()
          : defaults.telegram.botToken,
      webhookUrl:
        typeof telegramInput.webhookUrl === "string"
          ? telegramInput.webhookUrl.trim()
          : defaults.telegram.webhookUrl,
      webhookSecret:
        typeof telegramInput.webhookSecret === "string"
          ? telegramInput.webhookSecret.trim()
          : defaults.telegram.webhookSecret,
    },
    modules: {
      todo: pickBoolean(modulesInput.todo, defaults.modules.todo),
      notes: pickBoolean(modulesInput.notes, defaults.modules.notes),
      automations: pickBoolean(
        modulesInput.automations,
        defaults.modules.automations,
      ),
    },
    updatedAt:
      typeof input?.updatedAt === "string" && input.updatedAt
        ? input.updatedAt
        : defaults.updatedAt,
  };
}

async function ensureSettingsFile() {
  await mkdir(dirname(SETTINGS_FILE), { recursive: true });

  try {
    await readFile(SETTINGS_FILE, "utf8");
  } catch (error) {
    if (error && error.code === "ENOENT") {
      const defaults = buildDefaultSettings();
      await writeFile(SETTINGS_FILE, JSON.stringify(defaults, null, 2), "utf8");
      return;
    }
    throw error;
  }
}

export async function readSettings() {
  await ensureSettingsFile();
  const raw = await readFile(SETTINGS_FILE, "utf8");
  try {
    return normalizeSettings(JSON.parse(raw));
  } catch (_error) {
    const defaults = buildDefaultSettings();
    await writeFile(SETTINGS_FILE, JSON.stringify(defaults, null, 2), "utf8");
    return defaults;
  }
}

export async function writeSettings(patch) {
  const current = await readSettings();
  const next = normalizeSettings({
    ...current,
    ...patch,
    telegram: {
      ...current.telegram,
      ...(patch?.telegram ?? {}),
    },
    modules: {
      ...current.modules,
      ...(patch?.modules ?? {}),
    },
    updatedAt: new Date().toISOString(),
  });

  await writeFile(SETTINGS_FILE, JSON.stringify(next, null, 2), "utf8");
  return next;
}

export function asSettingsSummary(settings) {
  return {
    appName: settings.appName,
    setupCompleted: settings.setupCompleted,
    telegram: {
      hasBotToken: Boolean(settings.telegram.botToken),
      webhookUrl: settings.telegram.webhookUrl,
      hasWebhookSecret: Boolean(settings.telegram.webhookSecret),
    },
    modules: settings.modules,
    updatedAt: settings.updatedAt,
  };
}
