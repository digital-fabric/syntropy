import * as Tools from './tools.js';

export function buildExchangeBody(prompt) {
  return {
    model: "google/gemma-4-26b-a4b-it",
    messages: [
      {
        role: "user",
        content: prompt
      }
    ],
    tools: Tools.spec()
  };
  
}

export async function query(ctx) {
  const api_key = window.OPEN_ROUTER_API_KEY;
  const response = await fetch(
    "https://openrouter.ai/api/v1/chat/completions",
    {
      method: "POST",
      headers: {
        "Authorization": `Bearer ${api_key}`,
        "Content-Type": "application/json"
      },
      body: JSON.stringify(ctx)
    }
  );
  return await response.json();
}

export function addMessage(ctx, message) {
  ctx.messages.push(message);
}

export function mergeToolResults(ctx, tool_results) {
  tool_results.forEach((r) => {
    addMessage(ctx, {
      role: "tool",
      tool_call_id: r.id,
      content: JSON.stringify(r.result)
    });
  });
}
