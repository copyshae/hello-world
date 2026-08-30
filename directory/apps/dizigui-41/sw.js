/* 蔡禮旭老師｜細講弟子規 1～41 集 */
const CACHE = "dizigui41-v7";
const ASSETS = [
  "./",
  "./index.html",
  "./share.html",
  "./episodes.js",
  "./manifest.json",
  "./dizigui-icon-180.png",
  "./dizigui-icon-192.png",
  "./dizigui-icon-512.png"
];

self.addEventListener("install", (event) => {
  event.waitUntil(
    caches.open(CACHE).then((cache) => cache.addAll(ASSETS)).then(() => self.skipWaiting())
  );
});

self.addEventListener("message", (event) => {
  if (event.data && event.data.type === "SKIP_WAITING") self.skipWaiting();
});

self.addEventListener("activate", (event) => {
  event.waitUntil(
    caches.keys().then((keys) =>
      Promise.all(keys.filter((k) => k.startsWith("dizigui41-") && k !== CACHE).map((k) => caches.delete(k)))
    ).then(() => self.clients.claim())
  );
});

self.addEventListener("fetch", (event) => {
  const req = event.request;
  if (req.method !== "GET") return;
  const url = new URL(req.url);
  const path = url.pathname;

  // 圖示一律走網路優先，避免主畫面仍顯示舊圖
  if (/dizigui-icon-\d+\.png$/i.test(path) || /icon-\d+\.png$/i.test(path)) {
    event.respondWith(
      fetch(req)
        .then((res) => {
          const copy = res.clone();
          caches.open(CACHE).then((cache) => cache.put(req, copy));
          return res;
        })
        .catch(() => caches.match(req))
    );
    return;
  }

  if (/index\.html$/i.test(path) || path.endsWith("/dizigui-41/") || path.endsWith("/dizigui-41")) {
    event.respondWith(
      fetch(req)
        .then((res) => {
          const copy = res.clone();
          caches.open(CACHE).then((cache) => cache.put(req, copy));
          return res;
        })
        .catch(() => caches.match(req))
    );
    return;
  }

  event.respondWith(
    caches.match(req).then((cached) => {
      const live = fetch(req)
        .then((res) => {
          const copy = res.clone();
          caches.open(CACHE).then((cache) => cache.put(req, copy));
          return res;
        })
        .catch(() => cached);
      return cached || live;
    })
  );
});
