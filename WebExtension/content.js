// LibreBlock content script: reports blocked-resource statistics for the
// page badge and offers a per-site toggle message channel. Blocking itself
// is done by the compiled content blocker rules; this script only counts.

(() => {
  "use strict";

  let blocked = 0;
  const report = () => {
    browser.runtime.sendMessage({
      type: "page-stats",
      blocked,
      url: location.host
    }).catch(() => {
      // Extension context may be gone; ignore.
    });
  };

  // Count requests the content blockers cancelled by observing the
  // performance timeline for failed resource loads.
  const observer = new PerformanceObserver((list) => {
    for (const entry of list.getEntries()) {
      if (entry.name && entry.responseStatus === 0 && entry.decodingInfo) {
        blocked += 1;
      }
    }
  });
  try {
    observer.observe({ entryTypes: ["resource"] });
  } catch (_) {
    // Older engines: no observation possible; counts stay zero.
  }

  // Report on load and on unload.
  window.addEventListener("load", report);
  window.addEventListener("pagehide", report);

  // Listen for per-site toggle commands from the popup.
  browser.runtime.onMessage.addListener((message) => {
    if (message && message.type === "get-stats") {
      return Promise.resolve({ blocked, host: location.host });
    }
  });
})();
