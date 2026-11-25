// LibreBlock popup: shows the current page's block count. Updates happen
// in the app (native messaging is unavailable in iOS Safari).

"use strict";

const hostEl = document.getElementById("host");
const countEl = document.getElementById("blocked-count");
const openBtn = document.getElementById("open-app");

async function init() {
  const tabs = await browser.tabs.query({ active: true, currentWindow: true });
  const tab = tabs[0];
  try {
    hostEl.textContent = tab ? new URL(tab.url).host : "LibreBlock";
  } catch (_) {
    hostEl.textContent = "LibreBlock";
  }

  if (tab) {
    try {
      const stats = await browser.runtime.sendMessage({ type: "query-stats", tabId: tab.id });
      if (stats) {
        countEl.textContent = String(stats.blocked || 0);
      }
    } catch (_) {
      // No content script on this page (e.g. about:blank).
      countEl.textContent = "0";
    }
  }
}

// On iOS the extension can open its containing app via the standard scheme.
openBtn.addEventListener("click", async () => {
  try {
    await browser.tabs.create({ url: "libreblock://open" });
    window.close();
  } catch (_) {
    // Scheme unregistered: fail silently, the hint text explains the path.
  }
});

init();
