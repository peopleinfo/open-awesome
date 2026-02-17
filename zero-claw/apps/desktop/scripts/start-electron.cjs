const path = require("node:path");
const { spawn } = require("node:child_process");

// Some shells export ELECTRON_RUN_AS_NODE=1 globally, which breaks desktop startup.
delete process.env.ELECTRON_RUN_AS_NODE;

const electronBinary = require("electron");
const appRoot = path.resolve(__dirname, "..");

const child = spawn(electronBinary, [appRoot], {
  cwd: appRoot,
  stdio: "inherit",
  env: process.env,
  windowsHide: false,
});

child.on("close", (code, signal) => {
  if (code === null) {
    console.error(`electron exited from signal ${signal}`);
    process.exit(1);
    return;
  }
  process.exit(code);
});
