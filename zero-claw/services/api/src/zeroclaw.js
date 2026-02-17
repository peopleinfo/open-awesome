import { createWriteStream, existsSync } from "node:fs";
import { mkdir, readFile, writeFile } from "node:fs/promises";
import { dirname, join } from "node:path";
import { spawn } from "node:child_process";
import { fileURLToPath } from "node:url";
import { homedir } from "node:os";

const GATEWAY_LOG_PATH = new URL("../../../data/zeroclaw-gateway.log", import.meta.url);
const GATEWAY_LOG_FILE = fileURLToPath(GATEWAY_LOG_PATH);
const ZEROCLAW_CONFIG_FILE = join(homedir(), ".zeroclaw", "config.toml");
const CODEX_DEFAULT_PROVIDER = "openai";
const CODEX_DEFAULT_MODEL = "gpt-5.2-codex";

let gatewayProcess = null;
let gatewayStartedAt = null;
let gatewayExitInfo = null;
let installCache = null;
let installCacheAt = 0;
let installJob = {
  running: false,
  startedAt: null,
  finishedAt: null,
  ok: null,
  message: "",
  steps: [],
  error: "",
};

function escapeRegex(text) {
  return text.replace(/[.*+?^${}()|[\]\\]/g, "\\$&");
}

function parseTomlStringValue(text, key) {
  const matcher = new RegExp(
    `^\\s*${escapeRegex(key)}\\s*=\\s*"([^"\\r\\n]*)"\\s*$`,
    "m",
  );
  const match = text.match(matcher);
  return match ? match[1] : "";
}

function upsertTomlStringValue(text, key, value) {
  const line = `${key} = "${value}"`;
  const matcher = new RegExp(
    `^\\s*${escapeRegex(key)}\\s*=\\s*"[^"\\r\\n]*"\\s*$`,
    "m",
  );

  if (matcher.test(text)) {
    return text.replace(matcher, line);
  }

  if (!text) {
    return `${line}\n`;
  }

  const normalized = text.endsWith("\n") ? text : `${text}\n`;
  return `${line}\n${normalized}`;
}

function commandName() {
  const custom = process.env.ZEROCLAW_BIN;
  if (custom && custom.trim()) {
    return custom.trim();
  }

  const cargoBinPath = join(
    homedir(),
    ".cargo",
    "bin",
    process.platform === "win32" ? "zeroclaw.exe" : "zeroclaw",
  );
  if (existsSync(cargoBinPath)) {
    return cargoBinPath;
  }

  return process.platform === "win32" ? "zeroclaw.exe" : "zeroclaw";
}

function trimOutput(text, limit = 12000) {
  if (!text) {
    return "";
  }
  if (text.length <= limit) {
    return text;
  }
  const omitted = text.length - limit;
  return `${text.slice(0, limit)}\n... [${omitted} chars truncated]`;
}

function installationStatusFromVersion(versionResult) {
  return {
    installed: versionResult.ok && !versionResult.stderr.includes("not found"),
    versionText: (versionResult.stdout || versionResult.stderr || "").trim(),
    command: commandName(),
  };
}

function mergedEnv() {
  const env = { ...process.env };
  const sep = process.platform === "win32" ? ";" : ":";
  const currentPath = env.PATH || "";
  const cargoBinDir = join(homedir(), ".cargo", "bin");
  if (!currentPath.toLowerCase().includes(cargoBinDir.toLowerCase())) {
    env.PATH = currentPath ? `${currentPath}${sep}${cargoBinDir}` : cargoBinDir;
  }
  return env;
}

function shouldUseShell(cmd) {
  if (process.platform !== "win32") {
    return false;
  }
  const lower = cmd.toLowerCase();
  return lower.endsWith(".cmd") || lower.endsWith(".bat");
}

function normalizeLine(text) {
  return String(text || "").trim().toLowerCase();
}

function shouldFallbackToCodex(result) {
  const text = `${result?.stdout || ""}\n${result?.stderr || ""}`.toLowerCase();
  return (
    text.includes("all providers/models failed") ||
    text.includes("no api_key set") ||
    text.includes("authentication") ||
    text.includes("unauthorized") ||
    text.includes("invalid api key") ||
    text.includes("api key")
  );
}

function runCommand(args, options = {}) {
  const timeoutMs = options.timeoutMs ?? 120000;
  const cmd = commandName();

  return new Promise((resolve) => {
    const child = spawn(cmd, args, {
      windowsHide: true,
      stdio: ["ignore", "pipe", "pipe"],
      env: mergedEnv(),
      shell: shouldUseShell(cmd),
    });

    let stdout = "";
    let stderr = "";
    let timedOut = false;

    const timer = setTimeout(() => {
      timedOut = true;
      child.kill();
    }, timeoutMs);

    child.stdout.on("data", (chunk) => {
      stdout += String(chunk);
    });

    child.stderr.on("data", (chunk) => {
      stderr += String(chunk);
    });

    child.on("error", (error) => {
      clearTimeout(timer);
      resolve({
        ok: false,
        code: null,
        timedOut: false,
        command: `${cmd} ${args.join(" ")}`.trim(),
        stdout: "",
        stderr: error?.code === "ENOENT"
          ? `ZeroClaw CLI not found: "${cmd}". Install zeroclaw first.`
          : String(error?.message || error),
      });
    });

    child.on("close", (code) => {
      clearTimeout(timer);
      resolve({
        ok: code === 0 && !timedOut,
        code,
        timedOut,
        command: `${cmd} ${args.join(" ")}`.trim(),
        stdout: trimOutput(stdout),
        stderr: trimOutput(stderr),
      });
    });
  });
}

function runHostCommand(cmd, args, options = {}) {
  const timeoutMs = options.timeoutMs ?? 120000;
  const cwd = options.cwd || process.cwd();

  return new Promise((resolve) => {
    const child = spawn(cmd, args, {
      windowsHide: true,
      stdio: ["ignore", "pipe", "pipe"],
      env: mergedEnv(),
      shell: shouldUseShell(cmd),
      cwd,
    });

    let stdout = "";
    let stderr = "";
    let timedOut = false;

    const timer = setTimeout(() => {
      timedOut = true;
      child.kill();
    }, timeoutMs);

    child.stdout.on("data", (chunk) => {
      stdout += String(chunk);
    });

    child.stderr.on("data", (chunk) => {
      stderr += String(chunk);
    });

    child.on("error", (error) => {
      clearTimeout(timer);
      resolve({
        ok: false,
        code: null,
        timedOut: false,
        command: `${cmd} ${args.join(" ")}`.trim(),
        stdout: "",
        stderr: String(error?.message || error),
      });
    });

    child.on("close", (code) => {
      clearTimeout(timer);
      resolve({
        ok: code === 0 && !timedOut,
        code,
        timedOut,
        command: `${cmd} ${args.join(" ")}`.trim(),
        stdout: trimOutput(stdout),
        stderr: trimOutput(stderr),
      });
    });
  });
}

async function commandExists(cmd) {
  if (process.platform === "win32") {
    const result = await runHostCommand("where", [cmd], { timeoutMs: 10000 });
    return result.ok;
  }
  const result = await runHostCommand("which", [cmd], { timeoutMs: 10000 });
  return result.ok;
}

export async function readGatewayLogs(tail = 200) {
  try {
    const raw = await readFile(GATEWAY_LOG_FILE, "utf8");
    const lines = raw.split(/\r?\n/);
    const safeTail = Math.min(Math.max(Number(tail) || 200, 20), 1000);
    return {
      ok: true,
      lines: lines.slice(-safeTail).join("\n"),
      tail: safeTail,
    };
  } catch (error) {
    if (error?.code === "ENOENT") {
      return { ok: true, lines: "", tail };
    }
    return { ok: false, lines: "", tail, error: String(error?.message || error) };
  }
}

export function getGatewayState() {
  const running =
    Boolean(gatewayProcess) &&
    gatewayProcess.exitCode === null &&
    !gatewayProcess.killed;
  const pid = running ? gatewayProcess.pid : null;
  const uptimeSeconds =
    running && gatewayStartedAt
      ? Math.floor((Date.now() - gatewayStartedAt) / 1000)
      : 0;

  return {
    running,
    pid,
    uptimeSeconds,
    lastExit: gatewayExitInfo,
  };
}

export async function statusSummary() {
  const zeroclaw = await zeroClawInstallationStatus();
  const defaults = await zeroClawConfigStatus();
  return {
    zeroclaw,
    defaults,
    gateway: getGatewayState(),
  };
}

export async function zeroClawConfigStatus() {
  const install = await zeroClawInstallationStatus();
  if (!install.installed) {
    return {
      ok: false,
      exists: false,
      path: ZEROCLAW_CONFIG_FILE,
      defaultProvider: "",
      defaultModel: "",
      codexDefaults: false,
      target: {
        provider: CODEX_DEFAULT_PROVIDER,
        model: CODEX_DEFAULT_MODEL,
      },
      error: "ZeroClaw CLI is not installed.",
    };
  }

  try {
    const raw = await readFile(ZEROCLAW_CONFIG_FILE, "utf8");
    const defaultProvider = parseTomlStringValue(raw, "default_provider");
    const defaultModel = parseTomlStringValue(raw, "default_model");
    return {
      ok: true,
      exists: true,
      path: ZEROCLAW_CONFIG_FILE,
      defaultProvider,
      defaultModel,
      codexDefaults:
        defaultProvider === CODEX_DEFAULT_PROVIDER &&
        defaultModel === CODEX_DEFAULT_MODEL,
      target: {
        provider: CODEX_DEFAULT_PROVIDER,
        model: CODEX_DEFAULT_MODEL,
      },
      error: "",
    };
  } catch (error) {
    if (error?.code === "ENOENT") {
      return {
        ok: false,
        exists: false,
        path: ZEROCLAW_CONFIG_FILE,
        defaultProvider: "",
        defaultModel: "",
        codexDefaults: false,
        target: {
          provider: CODEX_DEFAULT_PROVIDER,
          model: CODEX_DEFAULT_MODEL,
        },
        error:
          "ZeroClaw config.toml was not found. Run zeroclaw once or use GUI apply defaults.",
      };
    }
    return {
      ok: false,
      exists: false,
      path: ZEROCLAW_CONFIG_FILE,
      defaultProvider: "",
      defaultModel: "",
      codexDefaults: false,
      target: {
        provider: CODEX_DEFAULT_PROVIDER,
        model: CODEX_DEFAULT_MODEL,
      },
      error: String(error?.message || error),
    };
  }
}

export async function applyCodexDefaults() {
  const install = await zeroClawInstallationStatus();
  if (!install.installed) {
    return {
      ok: false,
      changed: false,
      error: "ZeroClaw CLI is not installed.",
      config: await zeroClawConfigStatus(),
    };
  }

  await mkdir(dirname(ZEROCLAW_CONFIG_FILE), { recursive: true });

  let current = "";
  try {
    current = await readFile(ZEROCLAW_CONFIG_FILE, "utf8");
  } catch (error) {
    if (error?.code !== "ENOENT") {
      return {
        ok: false,
        changed: false,
        error: String(error?.message || error),
        config: await zeroClawConfigStatus(),
      };
    }

    const probe = await runCommand(["status"], { timeoutMs: 15000 });
    if (!probe.ok) {
      return {
        ok: false,
        changed: false,
        error:
          "Could not initialize zeroclaw config automatically. Run 'zeroclaw status' once and retry.",
        probe,
        config: await zeroClawConfigStatus(),
      };
    }

    try {
      current = await readFile(ZEROCLAW_CONFIG_FILE, "utf8");
    } catch (readBackError) {
      return {
        ok: false,
        changed: false,
        error:
          "zeroclaw config.toml is still missing after initialization attempt.",
        probe,
        config: await zeroClawConfigStatus(),
      };
    }
  }

  let next = upsertTomlStringValue(
    current,
    "default_provider",
    CODEX_DEFAULT_PROVIDER,
  );
  next = upsertTomlStringValue(next, "default_model", CODEX_DEFAULT_MODEL);
  const changed = next !== current;

  if (changed) {
    await writeFile(ZEROCLAW_CONFIG_FILE, next, "utf8");
  }

  const config = await zeroClawConfigStatus();
  return {
    ok: config.codexDefaults,
    changed,
    error: config.codexDefaults ? "" : config.error || "Failed to apply Codex defaults.",
    config,
  };
}

export async function zeroClawInstallationStatus(force = false) {
  const now = Date.now();
  if (!force && installCache && now - installCacheAt < 5000) {
    return installCache;
  }

  const version = await runCommand(["--version"], { timeoutMs: 10000 });
  installCache = installationStatusFromVersion(version);
  installCacheAt = now;
  return installCache;
}

export async function startGateway(bind, port) {
  const current = getGatewayState();
  if (current.running) {
    return {
      ok: true,
      message: "Gateway is already running.",
      gateway: current,
    };
  }

  await mkdir(dirname(GATEWAY_LOG_FILE), { recursive: true });

  const args = ["gateway"];
  if (bind && String(bind).trim()) {
    args.push("--host", String(bind).trim());
  }
  if (Number.isInteger(port) && port > 0) {
    args.push("--port", String(port));
  }

  const cmd = commandName();
  const child = spawn(cmd, args, {
    windowsHide: true,
    stdio: ["ignore", "pipe", "pipe"],
    env: mergedEnv(),
    shell: shouldUseShell(cmd),
  });

  const logStream = createWriteStream(GATEWAY_LOG_FILE, { flags: "a" });
  logStream.write(
    `\n[${new Date().toISOString()}] starting: ${cmd} ${args.join(" ")}\n`,
  );
  child.stdout.pipe(logStream);
  child.stderr.pipe(logStream);

  gatewayProcess = child;
  gatewayStartedAt = Date.now();
  gatewayExitInfo = null;

  child.on("error", (error) => {
    gatewayExitInfo = {
      at: new Date().toISOString(),
      code: null,
      signal: null,
      message: String(error?.message || error),
    };
    gatewayProcess = null;
    gatewayStartedAt = null;
  });

  child.on("close", (code, signal) => {
    gatewayExitInfo = {
      at: new Date().toISOString(),
      code,
      signal,
      message: code === 0 ? "Gateway exited normally." : "Gateway stopped.",
    };
    gatewayProcess = null;
    gatewayStartedAt = null;
  });

  await new Promise((resolve) => setTimeout(resolve, 750));
  const running = getGatewayState();
  if (!running.running) {
    return {
      ok: false,
      message:
        "Gateway failed to start. Check logs from /api/zeroclaw/gateway/logs.",
      gateway: running,
    };
  }

  return {
    ok: true,
    message: "Gateway started.",
    gateway: running,
  };
}

export async function stopGateway() {
  const current = getGatewayState();
  if (!current.running || !gatewayProcess) {
    return { ok: true, message: "Gateway is not running.", gateway: current };
  }

  gatewayProcess.kill();
  await new Promise((resolve) => setTimeout(resolve, 400));
  return {
    ok: true,
    message: "Gateway stop signal sent.",
    gateway: getGatewayState(),
  };
}

export async function runDoctor() {
  return runCommand(["doctor"], { timeoutMs: 120000 });
}

export async function runChannelsDoctor() {
  return runCommand(["channel", "doctor"], { timeoutMs: 120000 });
}

export async function runAgentPrompt(message) {
  const primary = await runCommand(["agent", "-m", message], { timeoutMs: 180000 });
  if (primary.ok) {
    return {
      ...primary,
      engine: "zeroclaw",
    };
  }

  if (!shouldFallbackToCodex(primary)) {
    return {
      ...primary,
      engine: "zeroclaw",
    };
  }

  const codexAvailable = await commandExists("codex");
  if (!codexAvailable) {
    return {
      ...primary,
      engine: "zeroclaw",
      oauthFallback: {
        ok: false,
        error: "Codex CLI is not installed. Run `codex login` after installing Codex CLI.",
      },
    };
  }

  const login = await runHostCommand("codex", ["login", "status"], { timeoutMs: 15000 });
  const loginText = normalizeLine(`${login.stdout}\n${login.stderr}`);
  const loggedIn = login.ok && loginText.includes("logged in");
  if (!loggedIn) {
    return {
      ...primary,
      engine: "zeroclaw",
      oauthFallback: {
        ok: false,
        error: "Codex OAuth is not active. Run `codex login` and retry.",
        login,
      },
    };
  }

  const codex = await runHostCommand(
    "codex",
    [
      "-a",
      "never",
      "exec",
      "-C",
      process.cwd(),
      "-s",
      "read-only",
      "--color",
      "never",
      message,
    ],
    { timeoutMs: 4 * 60 * 1000 },
  );

  if (codex.ok) {
    return {
      ...codex,
      engine: "codex-oauth",
      note:
        "zeroclaw provider failed; prompt was handled with Codex OAuth fallback.",
      zeroclawFailure: primary,
    };
  }

  return {
    ...primary,
    engine: "zeroclaw",
    oauthFallback: {
      ok: false,
      error: "Codex OAuth fallback failed.",
      result: codex,
    },
  };
}

export async function installZeroClaw(onStep) {
  const sourceDir = fileURLToPath(new URL("../../../data/zeroclaw-src", import.meta.url));
  const steps = [];
  const pushStep = (step) => {
    steps.push(step);
    if (typeof onStep === "function") {
      onStep(steps.slice());
    }
  };

  const gitAvailable = await commandExists("git");
  if (!gitAvailable) {
    return {
      ok: false,
      error: "git is required but not found in PATH.",
      steps,
    };
  }

  const cargoAvailable = await commandExists("cargo");
  if (!cargoAvailable) {
    if (process.platform === "win32") {
      const wingetAvailable = await commandExists("winget");
      if (!wingetAvailable) {
        return {
          ok: false,
          error:
            "cargo is not installed and winget is unavailable. Install Rust from https://rustup.rs and retry.",
          steps,
        };
      }

      const rustInstall = await runHostCommand(
        "winget",
        [
          "install",
          "Rustlang.Rustup",
          "-e",
          "--accept-package-agreements",
          "--accept-source-agreements",
        ],
        { timeoutMs: 20 * 60 * 1000 },
      );
      pushStep(rustInstall);
      if (!rustInstall.ok) {
        return {
          ok: false,
          error: "Failed to install Rust toolchain via winget.",
          steps,
        };
      }
    } else {
      return {
        ok: false,
        error:
          "cargo is not installed. Install Rust toolchain from https://rustup.rs and retry.",
        steps,
      };
    }
  }

  await mkdir(dirname(sourceDir), { recursive: true });
  if (existsSync(sourceDir)) {
    const pull = await runHostCommand(
      "git",
      ["-C", sourceDir, "pull", "--ff-only"],
      { timeoutMs: 3 * 60 * 1000 },
    );
    pushStep(pull);
    if (!pull.ok) {
      return {
        ok: false,
        error: "Failed to update local zeroclaw source checkout.",
        steps,
      };
    }
  } else {
    const clone = await runHostCommand(
      "git",
      ["clone", "https://github.com/zeroclaw-labs/zeroclaw.git", sourceDir],
      { timeoutMs: 3 * 60 * 1000 },
    );
    pushStep(clone);
    if (!clone.ok) {
      return {
        ok: false,
        error: "Failed to clone zeroclaw repository.",
        steps,
      };
    }
  }

  const install = await runHostCommand(
    "cargo",
    ["install", "--path", ".", "--force", "--locked"],
    { timeoutMs: 30 * 60 * 1000, cwd: sourceDir },
  );
  pushStep(install);
  if (!install.ok) {
    return {
      ok: false,
      error:
        "Failed to build/install zeroclaw. On Windows, ensure Visual Studio Build Tools with Desktop C++ workload is installed.",
      steps,
    };
  }

  const version = await runCommand(["--version"], { timeoutMs: 15000 });
  pushStep(version);
  installCache = installationStatusFromVersion(version);
  installCacheAt = Date.now();

  if (!version.ok) {
    return {
      ok: false,
      error: "zeroclaw installation finished but version verification failed.",
      steps,
    };
  }

  return {
    ok: true,
    message: "zeroclaw installed successfully.",
    steps,
    zeroclaw: installCache,
  };
}

export function getInstallJobStatus() {
  return {
    ...installJob,
    steps: Array.isArray(installJob.steps) ? installJob.steps.slice(-8) : [],
  };
}

export function startInstallZeroClawJob() {
  if (installJob.running) {
    return {
      ok: true,
      started: false,
      message: "Installation is already running.",
      job: getInstallJobStatus(),
    };
  }

  installJob = {
    running: true,
    startedAt: new Date().toISOString(),
    finishedAt: null,
    ok: null,
    message: "Installation started.",
    steps: [],
    error: "",
  };

  (async () => {
    try {
      const result = await installZeroClaw((steps) => {
        installJob = {
          ...installJob,
          steps,
        };
      });
      installJob = {
        ...installJob,
        running: false,
        finishedAt: new Date().toISOString(),
        ok: result.ok,
        message: result.message || (result.ok ? "Installed." : "Install failed."),
        steps: result.steps || [],
        error: result.ok ? "" : result.error || "Install failed.",
      };
    } catch (error) {
      installJob = {
        ...installJob,
        running: false,
        finishedAt: new Date().toISOString(),
        ok: false,
        message: "Install failed.",
        error: String(error?.message || error),
      };
    }
  })();

  return {
    ok: true,
    started: true,
    message: "Installation started.",
    job: getInstallJobStatus(),
  };
}
