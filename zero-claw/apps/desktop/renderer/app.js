const sectionTitles = {
  overview: "Overview",
  setup: "Setup Wizard",
  todos: "Todo Module",
  integrations: "Integrations",
  agent: "Agent Module",
};

const ALLOWED_WHEN_LOCKED = new Set(["setup", "agent"]);

const appTitle = document.getElementById("app-title");
const apiMeta = document.getElementById("api-meta");
const pageTitle = document.getElementById("page-title");
const statusText = document.getElementById("status-text");
const todoMeta = document.getElementById("todo-meta");
const setupOutput = document.getElementById("setup-output");
const setupLock = document.getElementById("setup-lock");

const checkSetupCompleted = document.getElementById("check-setup-completed");
const checkZeroClawInstalled = document.getElementById("check-zeroclaw-installed");
const checkTelegramToken = document.getElementById("check-telegram-token");
const checkTelegramWebhook = document.getElementById("check-telegram-webhook");
const checkCodexDefaults = document.getElementById("check-codex-defaults");
const installZeroClawButton = document.getElementById("install-zeroclaw-btn");
const setupCodexButton = document.getElementById("setup-codex-btn");
const completeSetupButton = document.getElementById("complete-setup-btn");
const refreshReadinessButton = document.getElementById("refresh-readiness-btn");

const todoForm = document.getElementById("todo-form");
const todoTitleInput = document.getElementById("todo-title");
const todoListElement = document.getElementById("todo-list");
const refreshButton = document.getElementById("refresh-btn");

const setupForm = document.getElementById("setup-form");
const setupAppNameInput = document.getElementById("setup-app-name");
const setupBotTokenInput = document.getElementById("setup-bot-token");
const setupWebhookUrlInput = document.getElementById("setup-webhook-url");
const setupWebhookSecretInput = document.getElementById("setup-webhook-secret");
const setupProbeButton = document.getElementById("probe-setup-btn");
const setupWebhookButton = document.getElementById("webhook-setup-btn");

const agentInstalled = document.getElementById("agent-installed");
const agentVersion = document.getElementById("agent-version");
const agentProvider = document.getElementById("agent-provider");
const agentModel = document.getElementById("agent-model");
const agentGateway = document.getElementById("agent-gateway");
const agentPid = document.getElementById("agent-pid");
const agentBindInput = document.getElementById("agent-bind");
const agentPortInput = document.getElementById("agent-port");
const agentRefreshButton = document.getElementById("agent-refresh");
const agentStartButton = document.getElementById("agent-start");
const agentStopButton = document.getElementById("agent-stop");
const agentDoctorButton = document.getElementById("agent-doctor");
const agentChannelDoctorButton = document.getElementById("agent-channel-doctor");
const agentLogsButton = document.getElementById("agent-logs");
const agentPromptForm = document.getElementById("agent-prompt-form");
const agentPromptInput = document.getElementById("agent-prompt");
const agentOutput = document.getElementById("agent-output");

let activeSection = "overview";
let cachedSettings = null;
let workspaceReady = false;

function setStatus(message) {
  statusText.textContent = message;
}

function setSetupOutput(text) {
  setupOutput.textContent = text || "";
}

function setAgentOutput(text) {
  agentOutput.textContent = text || "";
}

function formatTime(isoText) {
  try {
    return new Date(isoText).toLocaleString();
  } catch (_error) {
    return isoText;
  }
}

function toPrettyJson(value) {
  return JSON.stringify(value, null, 2);
}

function markChecklistItem(element, ok, label) {
  element.classList.remove("ok", "pending", "optional");
  element.classList.add(ok ? "ok" : "pending");
  element.textContent = `${label}: ${ok ? "ok" : "pending"}`;
}

function markOptionalChecklistItem(element, ok, label) {
  element.classList.remove("ok", "pending", "optional");
  if (ok) {
    element.classList.add("ok");
    element.textContent = `${label} (optional): set`;
    return;
  }
  element.classList.add("optional");
  element.textContent = `${label} (optional): not set`;
}

function applyReadiness(readiness) {
  workspaceReady = Boolean(readiness?.ready);
  const checks = readiness?.checks || {};

  markChecklistItem(checkSetupCompleted, Boolean(checks.setupCompleted), "Setup completion flag");
  markChecklistItem(
    checkZeroClawInstalled,
    Boolean(checks.zeroclawInstalled),
    "ZeroClaw CLI installed",
  );
  markChecklistItem(
    checkTelegramToken,
    Boolean(checks.hasTelegramBotToken),
    "Telegram bot token saved",
  );
  markOptionalChecklistItem(
    checkTelegramWebhook,
    Boolean(checks.hasTelegramWebhookUrl),
    "Telegram webhook URL saved",
  );
  markOptionalChecklistItem(
    checkCodexDefaults,
    Boolean(checks.codexDefaultsConfigured),
    "Codex defaults configured",
  );

  setupLock.classList.toggle("hidden", workspaceReady);
  completeSetupButton.disabled = workspaceReady;

  for (const button of document.querySelectorAll(".nav-btn")) {
    const section = button.getAttribute("data-section") || "";
    const locked = !workspaceReady && !ALLOWED_WHEN_LOCKED.has(section);
    button.classList.toggle("locked", locked);
  }

  if (!workspaceReady && !ALLOWED_WHEN_LOCKED.has(activeSection)) {
    activateSection("setup", { force: true });
    setStatus("Complete Setup Wizard requirements first.");
  }

  if (!workspaceReady) {
    todoMeta.textContent = "Locked until setup is complete.";
    todoListElement.innerHTML = "";
  }
}

function activateSection(section, options = {}) {
  let next = section in sectionTitles ? section : "overview";
  if (!options.force && !workspaceReady && !ALLOWED_WHEN_LOCKED.has(next)) {
    next = "setup";
    setStatus("Setup is required before using this module.");
  }

  activeSection = next;
  for (const element of document.querySelectorAll(".section")) {
    element.classList.toggle(
      "active",
      element.getAttribute("data-section") === activeSection,
    );
  }
  for (const button of document.querySelectorAll(".nav-btn")) {
    button.classList.toggle(
      "active",
      button.getAttribute("data-section") === activeSection,
    );
  }
  pageTitle.textContent = sectionTitles[activeSection];
}

function createButton(label, className, onClick) {
  const button = document.createElement("button");
  button.type = "button";
  button.textContent = label;
  if (className) {
    button.className = className;
  }
  button.addEventListener("click", onClick);
  return button;
}

async function loadApiMeta() {
  const apiBase = await window.zeroClaw.app.apiBase();
  apiMeta.textContent = `API ${apiBase}`;
}

function fillSetupForm(settings) {
  setupAppNameInput.value = settings.appName || "Zero Claw";
  setupWebhookUrlInput.value = settings.telegram?.webhookUrl || "";
  setupBotTokenInput.value = "";
  setupWebhookSecretInput.value = "";
  appTitle.textContent = settings.appName || "Zero Claw";
}

async function loadSettings() {
  const response = await window.zeroClaw.settings.get();
  cachedSettings = response.settings;
  fillSetupForm(response.settings);
}

async function refreshReadiness() {
  try {
    const response = await window.zeroClaw.settings.readiness();
    applyReadiness(response.readiness);
  } catch (error) {
    setStatus(`Failed to load readiness: ${error.message}`);
  }
}

async function saveSetup() {
  const tokenInput = setupBotTokenInput.value.trim();
  const payload = {
    appName: setupAppNameInput.value.trim() || "Zero Claw",
    telegram: {
      webhookUrl: setupWebhookUrlInput.value.trim(),
      webhookSecret: setupWebhookSecretInput.value.trim(),
    },
  };
  if (tokenInput) {
    payload.telegram.botToken = tokenInput;
  }

  const response = await window.zeroClaw.settings.update(payload);
  cachedSettings = response.settings;
  fillSetupForm(response.settings);
  return response.settings;
}

async function runHealthCheck() {
  try {
    const health = await window.zeroClaw.app.health();
    setStatus(
      `API healthy. ${health.todoCount} task(s). Ready=${health.setupReady ? "yes" : "no"}.`,
    );
  } catch (error) {
    setStatus(`Health check failed: ${error.message}`);
  }
}

async function refreshTodos() {
  todoMeta.textContent = "Loading todos...";
  try {
    const response = await window.zeroClaw.todos.list();
    renderTodos(response.todos || []);
    todoMeta.textContent = `Loaded ${response.todos.length} task(s) at ${new Date().toLocaleTimeString()}`;
  } catch (error) {
    todoMeta.textContent = `Failed to load todos: ${error.message}`;
  }
}

function renderTodos(todos) {
  todoListElement.innerHTML = "";

  if (todos.length === 0) {
    const empty = document.createElement("li");
    empty.className = "todo-item";
    empty.textContent = "No tasks yet. Add one from desktop or Telegram.";
    todoListElement.appendChild(empty);
    return;
  }

  for (const todo of todos) {
    const item = document.createElement("li");
    item.className = "todo-item";

    const toggle = document.createElement("input");
    toggle.type = "checkbox";
    toggle.checked = Boolean(todo.done);
    toggle.addEventListener("change", async () => {
      try {
        await window.zeroClaw.todos.update(todo.id, { done: toggle.checked });
        refreshTodos();
      } catch (error) {
        setStatus(`Failed to update todo ${todo.id}: ${error.message}`);
      }
    });

    const textWrap = document.createElement("div");
    const title = document.createElement("div");
    title.className = `todo-title${todo.done ? " done" : ""}`;
    title.textContent = todo.title;

    const meta = document.createElement("div");
    meta.className = "todo-meta";
    meta.textContent = `#${todo.id} via ${todo.source} | ${formatTime(todo.updatedAt)}`;

    textWrap.appendChild(title);
    textWrap.appendChild(meta);

    const actions = document.createElement("div");
    actions.className = "actions";

    const editButton = createButton("Edit", "alt", async () => {
      const nextTitle = window.prompt("Edit todo title:", todo.title);
      if (nextTitle === null) {
        return;
      }
      try {
        await window.zeroClaw.todos.update(todo.id, { title: nextTitle });
        refreshTodos();
      } catch (error) {
        setStatus(`Failed to edit todo ${todo.id}: ${error.message}`);
      }
    });

    const deleteButton = createButton("Delete", "delete", async () => {
      const confirmed = window.confirm(`Delete todo #${todo.id}?`);
      if (!confirmed) {
        return;
      }
      try {
        await window.zeroClaw.todos.remove(todo.id);
        refreshTodos();
      } catch (error) {
        setStatus(`Failed to delete todo ${todo.id}: ${error.message}`);
      }
    });

    actions.appendChild(editButton);
    actions.appendChild(deleteButton);

    item.appendChild(toggle);
    item.appendChild(textWrap);
    item.appendChild(actions);
    todoListElement.appendChild(item);
  }
}

function applyAgentStatus(status) {
  const installed = Boolean(status?.zeroclaw?.installed);
  const versionText = status?.zeroclaw?.versionText || "-";
  const defaults = status?.defaults || {};
  const gateway = status?.gateway ?? {};

  agentInstalled.textContent = installed ? "Yes" : "No";
  agentVersion.textContent = versionText;
  agentProvider.textContent = defaults.defaultProvider || "-";
  agentModel.textContent = defaults.defaultModel || "-";
  agentGateway.textContent = gateway.running
    ? `Running (${gateway.uptimeSeconds || 0}s)`
    : "Stopped";
  agentPid.textContent = gateway.pid ? String(gateway.pid) : "-";
}

async function refreshAgentStatus() {
  try {
    const status = await window.zeroClaw.zeroclaw.status();
    applyAgentStatus(status);
  } catch (error) {
    setStatus(`Failed to load ZeroClaw status: ${error.message}`);
    setAgentOutput(String(error.message));
  }
}

async function withAgentAction(label, action) {
  try {
    setStatus(label);
    const result = await action();
    setAgentOutput(toPrettyJson(result));
    await refreshAgentStatus();
    await refreshReadiness();
    setStatus("Action completed.");
  } catch (error) {
    setStatus(`Action failed: ${error.message}`);
    setAgentOutput(String(error.message));
  }
}

for (const button of document.querySelectorAll(".nav-btn")) {
  button.addEventListener("click", () => {
    activateSection(button.getAttribute("data-section") || "overview");
  });
}

for (const button of document.querySelectorAll("[data-go]")) {
  button.addEventListener("click", () => {
    activateSection(button.getAttribute("data-go") || "overview");
  });
}

todoForm.addEventListener("submit", async (event) => {
  event.preventDefault();
  const title = todoTitleInput.value.trim();
  if (!title) {
    return;
  }

  todoTitleInput.disabled = true;
  try {
    await window.zeroClaw.todos.create(title);
    todoTitleInput.value = "";
    setStatus("Todo created.");
    refreshTodos();
  } catch (error) {
    setStatus(`Failed to create todo: ${error.message}`);
  } finally {
    todoTitleInput.disabled = false;
    todoTitleInput.focus();
  }
});

refreshButton.addEventListener("click", () => {
  refreshTodos();
});

setupForm.addEventListener("submit", async (event) => {
  event.preventDefault();
  try {
    const settings = await saveSetup();
    setStatus("Setup settings saved.");
    setSetupOutput(toPrettyJson(settings));
    await refreshReadiness();
  } catch (error) {
    setStatus(`Failed to save setup: ${error.message}`);
    setSetupOutput(String(error.message));
  }
});

setupProbeButton.addEventListener("click", async () => {
  try {
    const botToken = setupBotTokenInput.value.trim();
    const response = await window.zeroClaw.settings.telegramProbe({
      botToken: botToken || undefined,
    });
    setStatus("Telegram token probe succeeded.");
    setSetupOutput(toPrettyJson(response));
    await refreshReadiness();
  } catch (error) {
    setStatus(`Telegram probe failed: ${error.message}`);
    setSetupOutput(String(error.message));
  }
});

setupWebhookButton.addEventListener("click", async () => {
  try {
    await saveSetup();
    const response = await window.zeroClaw.settings.setWebhook({
      botToken: setupBotTokenInput.value.trim() || undefined,
      webhookUrl: setupWebhookUrlInput.value.trim() || undefined,
      webhookSecret: setupWebhookSecretInput.value.trim() || undefined,
    });
    setStatus("Webhook applied. Finish checklist to unlock workspace.");
    setSetupOutput(toPrettyJson(response));
    await loadSettings();
    await refreshReadiness();
  } catch (error) {
    setStatus(`Failed to set webhook: ${error.message}`);
    setSetupOutput(String(error.message));
  }
});

setupCodexButton.addEventListener("click", async () => {
  try {
    const response = await window.zeroClaw.zeroclaw.applyCodexDefaults();
    setStatus("Codex defaults applied to zeroclaw config.");
    setSetupOutput(toPrettyJson(response));
    await refreshReadiness();
    await refreshAgentStatus();
  } catch (error) {
    setStatus(`Failed to apply Codex defaults: ${error.message}`);
    setSetupOutput(String(error.message));
  }
});

completeSetupButton.addEventListener("click", async () => {
  try {
    await saveSetup();
    const response = await window.zeroClaw.settings.completeSetup();
    setSetupOutput(toPrettyJson(response));
    await refreshReadiness();
    if (response?.readiness?.ready) {
      setStatus("Setup complete. Workspace unlocked.");
    } else {
      setStatus("Setup still incomplete. Check required checklist.");
    }
  } catch (error) {
    setStatus(`Cannot complete setup: ${error.message}`);
    setSetupOutput(String(error.message));
  }
});

installZeroClawButton.addEventListener("click", async () => {
  try {
    setStatus("Starting ZeroClaw install job...");
    const response = await window.zeroClaw.zeroclaw.install();
    setSetupOutput(toPrettyJson(response));

    const started = response?.started || response?.job?.running;
    if (!started) {
      await refreshAgentStatus();
      await refreshReadiness();
      setStatus("Installer was already running or completed.");
      return;
    }

    setStatus("Installing ZeroClaw CLI. Please wait...");
    for (let attempt = 0; attempt < 300; attempt += 1) {
      await new Promise((resolve) => setTimeout(resolve, 2000));
      const statusResponse = await window.zeroClaw.zeroclaw.installStatus();
      setSetupOutput(toPrettyJson(statusResponse));
      if (!statusResponse?.job?.running) {
        if (statusResponse?.job?.ok) {
          try {
            const codex = await window.zeroClaw.zeroclaw.applyCodexDefaults();
            setSetupOutput(toPrettyJson({ install: statusResponse, codex }));
          } catch (_error) {
            // Keep install success state even if codex defaults fail.
          }
        }
        await refreshAgentStatus();
        await refreshReadiness();
        if (statusResponse?.job?.ok) {
          setStatus("ZeroClaw install completed.");
        } else {
          setStatus(
            `ZeroClaw install failed: ${statusResponse?.job?.error || "unknown error"}`,
          );
        }
        return;
      }
    }

    setStatus("Install is still running. You can refresh checklist in a moment.");
  } catch (error) {
    setStatus(`ZeroClaw install failed: ${error.message}`);
    setSetupOutput(String(error.message));
  }
});

refreshReadinessButton.addEventListener("click", () => {
  refreshReadiness();
});

agentRefreshButton.addEventListener("click", () => {
  withAgentAction("Refreshing agent status...", async () =>
    window.zeroClaw.zeroclaw.status(),
  );
});

agentStartButton.addEventListener("click", () => {
  withAgentAction("Starting gateway...", async () => {
    const bind = agentBindInput.value.trim() || "127.0.0.1";
    const port = Number(agentPortInput.value.trim()) || 8080;
    return window.zeroClaw.zeroclaw.gatewayStart({ bind, port });
  });
});

agentStopButton.addEventListener("click", () => {
  withAgentAction("Stopping gateway...", async () =>
    window.zeroClaw.zeroclaw.gatewayStop(),
  );
});

agentDoctorButton.addEventListener("click", () => {
  withAgentAction("Running zeroclaw doctor...", async () =>
    window.zeroClaw.zeroclaw.doctor(),
  );
});

agentChannelDoctorButton.addEventListener("click", () => {
  withAgentAction("Running channel doctor...", async () =>
    window.zeroClaw.zeroclaw.channelsDoctor(),
  );
});

agentLogsButton.addEventListener("click", () => {
  withAgentAction("Loading gateway logs...", async () =>
    window.zeroClaw.zeroclaw.gatewayLogs({ tail: 300 }),
  );
});

agentPromptForm.addEventListener("submit", async (event) => {
  event.preventDefault();
  const message = agentPromptInput.value.trim();
  if (!message) {
    setStatus("Type a message before sending.");
    return;
  }

  await withAgentAction("Sending prompt to zeroclaw agent...", async () =>
    window.zeroClaw.zeroclaw.prompt({ message }),
  );
});

window.zeroClaw.events.onNavigate((section) => {
  activateSection(section);
});

window.zeroClaw.events.onRefresh(() => {
  refreshTodos();
  loadSettings();
  refreshAgentStatus();
  refreshReadiness();
});

window.zeroClaw.events.onHealth(() => {
  runHealthCheck();
});

activateSection("overview");
loadApiMeta();
loadSettings()
  .then(() => refreshReadiness())
  .then(() => {
    if (workspaceReady) {
      refreshTodos();
    }
  })
  .catch((error) => setStatus(`Failed to load settings: ${error.message}`));
refreshAgentStatus();
