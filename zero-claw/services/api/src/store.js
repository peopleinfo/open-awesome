import { mkdir, readFile, writeFile } from "node:fs/promises";
import { dirname } from "node:path";
import { fileURLToPath } from "node:url";

const STORE_PATH = new URL("../../../data/todos.json", import.meta.url);
const STORE_FILE = fileURLToPath(STORE_PATH);

async function ensureStore() {
  await mkdir(dirname(STORE_FILE), { recursive: true });

  try {
    await readFile(STORE_FILE, "utf8");
  } catch (error) {
    if (error && error.code === "ENOENT") {
      await writeFile(
        STORE_FILE,
        JSON.stringify({ lastId: 0, todos: [] }, null, 2),
        "utf8",
      );
      return;
    }

    throw error;
  }
}

async function readStore() {
  await ensureStore();
  const raw = await readFile(STORE_FILE, "utf8");
  const parsed = JSON.parse(raw);
  parsed.lastId = Number.isInteger(parsed.lastId) ? parsed.lastId : 0;
  parsed.todos = Array.isArray(parsed.todos) ? parsed.todos : [];
  return parsed;
}

async function writeStore(data) {
  await writeFile(STORE_FILE, JSON.stringify(data, null, 2), "utf8");
}

export async function listTodos() {
  const data = await readStore();
  return data.todos.sort((a, b) => a.id - b.id);
}

export async function createTodo(title, source = "desktop") {
  const data = await readStore();
  const now = new Date().toISOString();
  const todo = {
    id: data.lastId + 1,
    title,
    done: false,
    source,
    createdAt: now,
    updatedAt: now,
  };
  data.lastId = todo.id;
  data.todos.push(todo);
  await writeStore(data);
  return todo;
}

export async function updateTodo(id, patch, source = "desktop") {
  const data = await readStore();
  const index = data.todos.findIndex((todo) => todo.id === id);
  if (index < 0) {
    return null;
  }

  const current = data.todos[index];
  const next = {
    ...current,
    ...patch,
    source,
    updatedAt: new Date().toISOString(),
  };
  data.todos[index] = next;
  await writeStore(data);
  return next;
}

export async function deleteTodo(id) {
  const data = await readStore();
  const index = data.todos.findIndex((todo) => todo.id === id);
  if (index < 0) {
    return false;
  }

  data.todos.splice(index, 1);
  await writeStore(data);
  return true;
}
