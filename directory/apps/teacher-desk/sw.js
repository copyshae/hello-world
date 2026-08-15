/* 習作台：快取＋接收分享的掃描檔 */
const CACHE = "teacher-desk-v5";
const ASSETS = [
  "./",
  "./index.html",
  "./share.html",
  "./manifest.json",
  "./icon-180.png",
  "./icon-192.png",
  "./icon-512.png"
];

const DB_NAME = "teacher-desk-scans";
const DB_STORE = "inbox";

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

async function putScan(record) {
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

  // Web Share Target POST → 存 IndexedDB → 導回主畫面
  if (event.request.method === "POST" && url.pathname.endsWith("/share.html")) {
    event.respondWith(
      (async () => {
        try {
          const form = await event.request.formData();
          const files = form.getAll("scans").filter((f) => f && f.name);
          const now = Date.now();
          for (let i = 0; i < files.length; i++) {
            const f = files[i];
            const buf = await f.arrayBuffer();
            await putScan({
              id: "share-" + now + "-" + i,
              name: f.name || ("scan-" + (i + 1)),
              type: f.type || "application/octet-stream",
              size: buf.byteLength,
              buffer: buf,
              seatId: "",
              round: 1,
              createdAt: now,
              source: "share"
            });
          }
        } catch (e) {
          // still redirect
        }
        return Response.redirect("./index.html?inbox=1", 303);
      })()
    );
    return;
  }

  if (event.request.method !== "GET") return;
  event.respondWith(
    caches.match(event.request).then((hit) => {
      const net = fetch(event.request)
        .then((res) => {
          const copy = res.clone();
          caches.open(CACHE).then((c) => c.put(event.request, copy));
          return res;
        })
        .catch(() => hit);
      return hit || net;
    })
  );
});
