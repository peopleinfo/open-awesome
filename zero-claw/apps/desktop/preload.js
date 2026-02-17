const { contextBridge, ipcRenderer } = require("electron");

contextBridge.exposeInMainWorld("zeroClaw", {
  app: {
    apiBase: () => ipcRenderer.invoke("app:apiBase"),
    health: () => ipcRenderer.invoke("app:health"),
  },
  todos: {
    list: () => ipcRenderer.invoke("todo:list"),
    create: (title) => ipcRenderer.invoke("todo:create", { title }),
    update: (id, patch) => ipcRenderer.invoke("todo:update", { id, patch }),
    remove: (id) => ipcRenderer.invoke("todo:delete", { id }),
  },
  settings: {
    get: () => ipcRenderer.invoke("settings:get"),
    readiness: () => ipcRenderer.invoke("settings:readiness"),
    update: (payload) => ipcRenderer.invoke("settings:update", payload),
    completeSetup: () => ipcRenderer.invoke("settings:completeSetup"),
    telegramProbe: (payload) => ipcRenderer.invoke("settings:telegramProbe", payload),
    setWebhook: (payload) => ipcRenderer.invoke("settings:setWebhook", payload),
  },
  zeroclaw: {
    status: () => ipcRenderer.invoke("zeroclaw:status"),
    defaults: () => ipcRenderer.invoke("zeroclaw:defaults"),
    applyCodexDefaults: () => ipcRenderer.invoke("zeroclaw:applyCodexDefaults"),
    gatewayStart: (payload) => ipcRenderer.invoke("zeroclaw:gatewayStart", payload),
    gatewayStop: () => ipcRenderer.invoke("zeroclaw:gatewayStop"),
    gatewayLogs: (payload) => ipcRenderer.invoke("zeroclaw:gatewayLogs", payload),
    doctor: () => ipcRenderer.invoke("zeroclaw:doctor"),
    channelsDoctor: () => ipcRenderer.invoke("zeroclaw:channelsDoctor"),
    install: () => ipcRenderer.invoke("zeroclaw:install"),
    installStatus: () => ipcRenderer.invoke("zeroclaw:installStatus"),
    prompt: (payload) => ipcRenderer.invoke("zeroclaw:prompt", payload),
  },
  events: {
    onNavigate: (callback) => {
      ipcRenderer.on("app:navigate", (_event, section) => callback(section));
    },
    onHealth: (callback) => {
      ipcRenderer.on("app:health", callback);
    },
    onRefresh: (callback) => {
      ipcRenderer.on("app:refresh", callback);
    },
  },
});
