import MiniGFM from './minigfm.js'; // for UI

export function createNewSection() {
  const main = document.querySelector("main");
  const section = document.createElement("section");
  main.appendChild(section);
  return section;
}

export async function askPrompt(section) {
  return new Promise((resolve) => {
    setupForm(section, resolve);
  });
}

function setupForm(section, submit_callback) {
  const template = document.querySelector("#template-prompt-form");
  const form = document.importNode(template.content, true);
  section.appendChild(form);
  section
    .querySelector("#prompt-form")
    .addEventListener("submit", function (e) {
      e.preventDefault();
      submit_callback(section.querySelector("#prompt-text").value);
    });
  setTimeout(() => {
    section.querySelector("#prompt-text").focus();
  }, 50);
  
}

export function addSectionEntryMarkdown(section, md) {
  const parser = new MiniGFM({});
  const html = parser.parse(md);
  
  const ele = document.createElement("div");
  ele.innerHTML = html;
  section.appendChild(ele);
  return ele;
}

export function addPendingEntry(section) {
  const ele = addSectionEntryMarkdown(section, "*Waiting for response...*");
  ele.classList.add("pending");
}

export function removePendingEntry(section) {
  const ele = section.querySelector('.pending');
  if (ele) ele.remove();
}
