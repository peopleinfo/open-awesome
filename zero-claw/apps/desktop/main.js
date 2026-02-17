const path = require("node:path");
const { app, BrowserWindow, Menu, ipcMain } = require("electron");

const apiBase = process.env.ZERO_CLAW_API_URL || "http://127.0.0.1:3010";

async function apiRequest(route, options = {}) {
  const response = await fetch(`${apiBase}${route}`, {
    ...options,
    headers: {
      "content-type": "application/json",
      ...(options.headers || {}),
    },
  });

  const bodyText = await response.text();
  let body = {};
  if (bodyText) {
    try {
      body = JSON.parse(bodyText);
    } catch (_error) {
      body = { raw: bodyText };
    }
  }

  if (!response.ok) {
    const message =
      body.error ||
      body.message ||
      body.stderr ||
      body.stdout ||
      body.raw ||
      `request failed: ${response.status}`;
    throw new Error(message);
  }

  return body;
}

function createMenu(mainWindow) {
  const template = [
    {
      label: "File",
      submenu: [
        {
          label: "Overview",
          accelerator: "CmdOrCtrl+1",
          click: () => {
            mainWindow.webContents.send("app:navigate", "overview");
          },
        },
        {
          label: "Setup",
          accelerator: "CmdOrCtrl+2",
          click: () => {
            mainWindow.webContents.send("app:navigate", "setup");
          },
        },
        {
          label: "Todos",
          accelerator: "CmdOrCtrl+3",
          click: () => {
            mainWindow.webContents.send("app:navigate", "todos");
          },
        },
        {
          label: "Integrations",
          accelerator: "CmdOrCtrl+4",
          click: () => {
            mainWindow.webContents.send("app:navigate", "integrations");
          },
        },
        {
          label: "Agent",
          accelerator: "CmdOrCtrl+5",
          click: () => {
            mainWindow.webContents.send("app:navigate", "agent");
          },
        },
        { type: "separator" },
        {
          label: "Refresh Data",
          accelerator: "CmdOrCtrl+R",
          click: () => {
            mainWindow.webContents.send("app:refresh");
          },
        },
        { type: "separator" },
        { role: "quit" },
      ],
    },
    {
      label: "View",
      submenu: [{ role: "reload" }, { role: "toggledevtools" }],
    },
    {
      label: "Help",
      submenu: [
        {
          label: "API Health",
          click: () => {
            mainWindow.webContents.send("app:health");
          },
        },
      ],
    },
  ];

  const menu = Menu.buildFromTemplate(template);
  Menu.setApplicationMenu(menu);
}

function createWindow() {
  const window = new BrowserWindow({
    width: 1100,
    height: 760,
    minWidth: 760,
    minHeight: 560,
    backgroundColor: "#f8f4ec",
    webPreferences: {
      preload: path.join(__dirname, "preload.js"),
      contextIsolation: true,
      nodeIntegration: false,
    },
  });

  window.loadFile(path.join(__dirname, "renderer/index.html"));
  createMenu(window);
  return window;
}

ipcMain.handle("app:apiBase", async () => apiBase);
ipcMain.handle("app:health", async () => apiRequest("/health"));
ipcMain.handle("todo:list", async () => apiRequest("/api/todos"));
ipcMain.handle("todo:create", async (_event, payload) =>
  apiRequest("/api/todos", {
    method: "POST",
    body: JSON.stringify({ title: payload.title }),
  }),
);
ipcMain.handle("todo:update", async (_event, payload) =>
  apiRequest(`/api/todos/${payload.id}`, {
    method: "PUT",
    body: JSON.stringify(payload.patch),
  }),
);
ipcMain.handle("todo:delete", async (_event, payload) =>
  apiRequest(`/api/todos/${payload.id}`, {
    method: "DELETE",
  }),
);
ipcMain.handle("settings:get", async () => apiRequest("/api/settings"));
ipcMain.handle("settings:readiness", async () => apiRequest("/api/setup/readiness"));
ipcMain.handle("settings:update", async (_event, payload) =>
  apiRequest("/api/settings", {
    method: "PUT",
    body: JSON.stringify(payload),
  }),
);
ipcMain.handle("settings:completeSetup", async () =>
  apiRequest("/api/settings/complete-setup", {
    method: "POST",
    body: JSON.stringify({}),
  }),
);
ipcMain.handle("settings:telegramProbe", async (_event, payload) =>
  apiRequest("/api/settings/telegram/probe", {
    method: "POST",
    body: JSON.stringify(payload || {}),
  }),
);
ipcMain.handle("settings:setWebhook", async (_event, payload) =>
  apiRequest("/api/settings/telegram/set-webhook", {
    method: "POST",
    body: JSON.stringify(payload || {}),
  }),
);
ipcMain.handle("zeroclaw:status", async () => apiRequest("/api/zeroclaw/status"));
ipcMain.handle("zeroclaw:defaults", async () =>
  apiRequest("/api/zeroclaw/defaults"),
);
ipcMain.handle("zeroclaw:applyCodexDefaults", async () =>
  apiRequest("/api/zeroclaw/defaults/codex", {
    method: "POST",
    body: JSON.stringify({}),
  }),
);
ipcMain.handle("zeroclaw:gatewayStart", async (_event, payload) =>
  apiRequest("/api/zeroclaw/gateway/start", {
    method: "POST",
    body: JSON.stringify(payload || {}),
  }),
);
ipcMain.handle("zeroclaw:gatewayStop", async () =>
  apiRequest("/api/zeroclaw/gateway/stop", {
    method: "POST",
    body: JSON.stringify({}),
  }),
);
ipcMain.handle("zeroclaw:gatewayLogs", async (_event, payload) => {
  const tail = Number(payload?.tail) || 200;
  return apiRequest(`/api/zeroclaw/gateway/logs?tail=${tail}`);
});
ipcMain.handle("zeroclaw:doctor", async () =>
  apiRequest("/api/zeroclaw/doctor", {
    method: "POST",
    body: JSON.stringify({}),
  }),
);
ipcMain.handle("zeroclaw:channelsDoctor", async () =>
  apiRequest("/api/zeroclaw/channels-doctor", {
    method: "POST",
    body: JSON.stringify({}),
  }),
);
ipcMain.handle("zeroclaw:install", async () =>
  apiRequest("/api/zeroclaw/install", {
    method: "POST",
    body: JSON.stringify({}),
  }),
);
ipcMain.handle("zeroclaw:installStatus", async () =>
  apiRequest("/api/zeroclaw/install/status"),
);
ipcMain.handle("zeroclaw:prompt", async (_event, payload) =>
  apiRequest("/api/zeroclaw/agent/prompt", {
    method: "POST",
    body: JSON.stringify(payload || {}),
  }),
);

app.whenReady().then(() => {
  createWindow();

  app.on("activate", () => {
    if (BrowserWindow.getAllWindows().length === 0) {
      createWindow();
    }
  });
});

app.on("window-all-closed", () => {
  if (process.platform !== "darwin") {
    app.quit();
  }
});
