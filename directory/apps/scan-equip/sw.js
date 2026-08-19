/* 掃具台：離線快取 + 接收分享照片 */
const CACHE = "scan-equip-v20";
const ASSETS = [
  "./",
  "./index.html",
  "./share.html",
  "./manifest.json",
  "./icon-180.png",
  "./icon-192.png",
  "./icon-512.png"
];

const DB_NAME = "scan-equip-inbox";
const DB_STORE = "photos";

function openDb() {
  return new Promise((resolve, reject) => {
    const req = indexedDB.open(DB_NAME, 1);
    req.onupgradeneeded = () => {
      const db = req.result;
      if (!db.objectStoreNames.contains(DB_STORE)) {
        db.createObjectStore(DB_STORE, { keyPath: "id" });
      }
    };
    req.onsuccess = () => resolve(req.result);
    req.onerror = () => reject(req.error);
  });
}

async function putPhoto(record) {
  const db = await openDb();
  return new Promise((resolve, reject) => {
    const tx = db.transaction(DB_STORE, "readwrite");
    tx.objectStore(DB_STORE).put(record);
    tx.oncomplete = () => resolve();
    tx.onerror = () => reject(tx.error);
  });
}

self.addEventListener("install", (event) => {
  event.waitUntil(caches.open(CACHE).then((c) => c.addAll(ASSETS)));
  self.skipWaiting();
});

self.addEventListener("activate", (event) => {
  event.waitUntil(
    caches.keys().then((keys) =>
      Promise.all(keys.filter((k) => k !== CACHE).map((k) => caches.delete(k)))
    )
  );
  self.clients.claim();
});

self.addEventListener("fetch", (event) => {
  const url = new URL(event.request.url);

  if (event.request.method === "POST" && url.pathname.endsWith("/share.html")) {
    event.respondWith(
      (async () => {
        try {
          const form = await event.request.formData();
          const files = form.getAll("photos").filter((f) => f && f.name);
          const now = Date.now();
          for (let i = 0; i < files.length; i++) {
            const f = files[i];
            const buf = await f.arrayBuffer();
            await putPhoto({
              id: "share-" + now + "-" + i,
              name: f.name || "photo-" + (i + 1),
              type: f.type || "image/jpeg",
              size: buf.byteLength,
              buffer: buf,
              createdAt: now,
              source: "share"
            });
          }
        } catch (e) {
          /* still redirect */
        }
        return Response.redirect("./index.html?scan=1", 303);
      })()
    );
    return;
  }

  if (event.request.method !== "GET") return;
  // 網路優先：先嘗試從網路取得最新版本，離線時才回退到快取
  event.respondWith(
    fetch(event.request)
      .then((res) => {
        const copy = res.clone();
        caches.open(CACHE).then((c) => c.put(event.request, copy));
        return res;
      })
      .catch(() => caches.match(event.request))
  );
});
