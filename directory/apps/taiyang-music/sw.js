/* 太陽盛德導師｜歌曲連播 */
const CACHE = "taiyang-music-v21";
const ASSETS = [
  "./",
  "./index.html",
  "./share.html",
  "./manifest.json",
  "./catalog.json",
  "./lyrics/index.json",
  "./taiyang-icon-180.png",
  "./taiyang-icon-192.png",
  "./taiyang-icon-512.png"
];

self.addEventListener("install", (event) => {
  event.waitUntil(
    caches.open(CACHE).then((c) => c.addAll(ASSETS)).then(() => self.skipWaiting())
  );
});

self.addEventListener("message", (event) => {
  if (event.data && event.data.type === "SKIP_WAITING") self.skipWaiting();
});

self.addEventListener("activate", (event) => {
  event.waitUntil(
    caches.keys().then((keys) =>
      Promise.all(keys.filter((k) => k.startsWith("taiyang-music-") && k !== CACHE).map((k) => caches.delete(k)))
    ).then(() => self.clients.claim())
  );
});

self.addEventListener("fetch", (event) => {
  const req = event.request;
  if (req.method !== "GET") return;
  const path = new URL(req.url).pathname;

  if (/catalog\.json$/i.test(path) || /taiyang-icon-\d+\.png$/i.test(path) || /\/lyrics\/.+\.json$/i.test(path)) {
    event.respondWith(
      fetch(req).then((res) => {
        const copy = res.clone();
        caches.open(CACHE).then((c) => c.put(req, copy));
        return res;
      }).catch(() => caches.match(req))
    );
    return;
  }

  if (/index\.html$/i.test(path) || path.endsWith("/taiyang-music/") || path.endsWith("/taiyang-music")) {
    event.respondWith(
      fetch(req).then((res) => {
        const copy = res.clone();
        caches.open(CACHE).then((c) => c.put(req, copy));
        return res;
      }).catch(() => caches.match(req))
    );
    return;
  }

  event.respondWith(
    caches.match(req).then((cached) => {
      const live = fetch(req).then((res) => {
        const copy = res.clone();
        caches.open(CACHE).then((c) => c.put(req, copy));
        return res;
      }).catch(() => cached);
      return cached || live;
    })
  );
});
