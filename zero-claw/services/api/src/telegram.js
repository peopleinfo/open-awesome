function parseId(value) {
  const number = Number(value);
  if (!Number.isInteger(number) || number <= 0) {
    return null;
  }
  return number;
}

function formatTodoList(todos) {
  if (todos.length === 0) {
    return "Todo list is empty.";
  }

  return todos
    .map((todo) => {
      const marker = todo.done ? "[x]" : "[ ]";
      return `${marker} ${todo.id}. ${todo.title}`;
    })
    .join("\n");
}

function helpMessage() {
  return [
    "Available commands:",
    "/todo list",
    "/todo add <title>",
    "/todo done <id>",
    "/todo reopen <id>",
    "/todo delete <id>",
    "/todo help",
  ].join("\n");
}

function parseText(update) {
  return update?.message?.text ?? update?.edited_message?.text ?? "";
}

function parseChatId(update) {
  return (
    update?.message?.chat?.id ??
    update?.edited_message?.chat?.id ??
    update?.callback_query?.message?.chat?.id ??
    null
  );
}

export async function handleTelegramUpdate(update, store) {
  const text = parseText(update).trim();
  const chatId = parseChatId(update);

  if (!chatId) {
    return { handled: false, chatId: null, text: "No chat id in update." };
  }

  if (text === "/start") {
    return {
      handled: true,
      chatId,
      text: "Zero Claw bot is connected.\n" + helpMessage(),
    };
  }

  if (text === "/help" || text === "/todo help") {
    return { handled: true, chatId, text: helpMessage() };
  }

  if (text === "/todo list" || text === "/list") {
    const todos = await store.listTodos();
    return { handled: true, chatId, text: formatTodoList(todos) };
  }

  if (text.startsWith("/todo add ")) {
    const title = text.replace("/todo add ", "").trim();
    if (!title) {
      return { handled: true, chatId, text: "Usage: /todo add <title>" };
    }
    const todo = await store.createTodo(title, "telegram");
    return {
      handled: true,
      chatId,
      text: `Added todo ${todo.id}: ${todo.title}`,
    };
  }

  if (text.startsWith("/todo done ")) {
    const id = parseId(text.replace("/todo done ", "").trim());
    if (!id) {
      return { handled: true, chatId, text: "Usage: /todo done <id>" };
    }
    const updated = await store.updateTodo(id, { done: true }, "telegram");
    if (!updated) {
      return { handled: true, chatId, text: `Todo ${id} not found.` };
    }
    return { handled: true, chatId, text: `Marked todo ${id} as done.` };
  }

  if (text.startsWith("/todo reopen ")) {
    const id = parseId(text.replace("/todo reopen ", "").trim());
    if (!id) {
      return { handled: true, chatId, text: "Usage: /todo reopen <id>" };
    }
    const updated = await store.updateTodo(id, { done: false }, "telegram");
    if (!updated) {
      return { handled: true, chatId, text: `Todo ${id} not found.` };
    }
    return { handled: true, chatId, text: `Reopened todo ${id}.` };
  }

  if (text.startsWith("/todo delete ")) {
    const id = parseId(text.replace("/todo delete ", "").trim());
    if (!id) {
      return { handled: true, chatId, text: "Usage: /todo delete <id>" };
    }
    const deleted = await store.deleteTodo(id);
    if (!deleted) {
      return { handled: true, chatId, text: `Todo ${id} not found.` };
    }
    return { handled: true, chatId, text: `Deleted todo ${id}.` };
  }

  if (text.startsWith("/todo")) {
    return { handled: true, chatId, text: helpMessage() };
  }

  return { handled: false, chatId, text: "Command ignored." };
}

export async function sendTelegramMessage(botToken, chatId, text) {
  if (!botToken) {
    return { ok: false, reason: "TELEGRAM_BOT_TOKEN is missing." };
  }

  const response = await fetch(`https://api.telegram.org/bot${botToken}/sendMessage`, {
    method: "POST",
    headers: { "content-type": "application/json" },
    body: JSON.stringify({
      chat_id: chatId,
      text,
    }),
  });

  if (!response.ok) {
    const body = await response.text();
    return { ok: false, reason: `Telegram API error ${response.status}: ${body}` };
  }

  return { ok: true };
}
