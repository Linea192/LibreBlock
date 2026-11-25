// LibreBlock background script: tracks per-tab block counts reported by
// content scripts and shows them in the toolbar badge. Blocking itself is
// done by the six content blocker extensions; this is display-only.
//
// Note: native messaging is unavailable in Safari on iOS, so the popup
// cannot trigger filter updates; it links to the app instead.

const counts = new Map(); // tabId -> { blocked, host }

browser.runtime.onMessage.addListener((message, sender) => {
  if (!message || typeof message !== "object") return;

  if (message.type === "page-stats" && sender.tab) {
    counts.set(sender.tab.id, { blocked: message.blocked, host: message.url });
    const text = message.blocked > 0 ? String(message.blocked) : "";
    browser.action.setBadgeText({ text, tabId: sender.tab.id }).catch(() => {});
    return;
  }

  if (message.type === "query-stats") {
    return Promise.resolve(counts.get(message.tabId) || { blocked: 0, host: "" });
  }
});

browser.tabs.onRemoved.addListener((tabId) => counts.delete(tabId));
