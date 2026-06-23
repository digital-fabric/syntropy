import * as UI    from './ui.js';
import * as Model from './model.js';
import * as Tools from './tools.js';

export async function runPromptExchange(callHandler) {
  const section = UI.createNewSection();
  const prompt = await UI.askPrompt(section);
  UI.addSectionEntryMarkdown(section, `*Prompt*: ${prompt}`);
  const ctx = Model.buildExchangeBody(prompt);

  while (true) {
    UI.addPendingEntry(section);
    const response = await Model.query(ctx);
    UI.removePendingEntry(section);
    if (!(await processResponse(section, ctx, response, callHandler)))
      break;
  }
}

async function processResponse(section, ctx, response, callHandler) {
  const first_choice = response.choices[0];
  if (first_choice.finish_reason == "tool_calls") {
    Model.addMessage(ctx, first_choice.message);
    const tool_calls = first_choice.message.tool_calls;
    const tool_results = await performToolCalls(section, ctx, tool_calls, callHandler);
    console.log("tool results", tool_results);
    Model.mergeToolResults(ctx, tool_results);
    return true;
  }
  else if (first_choice.finish_reason == "stop") {
    UI.addSectionEntryMarkdown(section, first_choice.message.content);
    return false;
  }
  
}

async function performToolCalls(section, ctx, tool_calls, callHandler) {
  const pending = tool_calls.map(async (c) => await runTool(section, ctx, callHandler, c));
  return await Promise.all(pending);
}

async function runTool(section, ctx, callHandler, call) {
  UI.addSectionEntryMarkdown(section, `Running \`${call.function.name}(${call.function.arguments})\``);
  const name = call.function.name;
  const args = JSON.parse(call.function.arguments);
  try {
    const res = await callHandler(name, args);
    return {
      id: call.id,
      result: res
    }
  }
  catch (e) {
    return {
      id: call.id,
      error: e.message
    }
  }
}



runPromptExchange(Tools.toolHandler);
