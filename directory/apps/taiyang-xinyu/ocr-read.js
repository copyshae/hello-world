/** 太陽心語：從原圖辨識文字（CDN 檔名常與圖片內文不符） */
(function (global) {
  var CACHE_KEY = "taiyang-xinyu-ocr-cache";
  var tesseractPromise = null;

  function loadTesseract() {
    if (global.Tesseract) return Promise.resolve(global.Tesseract);
    if (!tesseractPromise) {
      tesseractPromise = new Promise(function (resolve, reject) {
        var s = document.createElement("script");
        s.src = "https://cdn.jsdelivr.net/npm/tesseract.js@5/dist/tesseract.min.js";
        s.onload = function () { resolve(global.Tesseract); };
        s.onerror = reject;
        document.head.appendChild(s);
      });
    }
    return tesseractPromise;
  }

  function getCache() {
    try { return JSON.parse(localStorage.getItem(CACHE_KEY) || "{}"); } catch (_) { return {}; }
  }

  function setCache(id, text) {
    var c = getCache();
    c[id] = text;
    localStorage.setItem(CACHE_KEY, JSON.stringify(c));
  }

  function cleanOcr(text) {
    return (text || "")
      .replace(/\s+/g, "")
      .replace(/[^\u4e00-\u9fff，。、；：！？「」《》—\-]/g, "")
      .trim();
  }

  function preprocessCanvas(img) {
    var c = document.createElement("canvas");
    var scale = Math.min(1, 1400 / (img.naturalWidth || 1));
    c.width = Math.max(1, Math.round((img.naturalWidth || 1) * scale));
    c.height = Math.max(1, Math.round((img.naturalHeight || 1) * scale));
    var ctx = c.getContext("2d");
    ctx.drawImage(img, 0, 0, c.width, c.height);
    var id = ctx.getImageData(0, 0, c.width, c.height);
    var d = id.data;
    for (var i = 0; i < d.length; i += 4) {
      var r = d[i], g = d[i + 1], b = d[i + 2];
      if (r > 155 && g > 115 && b < 145 && (r + g) > b * 2 + 70) {
        d[i] = d[i + 1] = d[i + 2] = 0;
        d[i + 3] = 255;
      } else {
        d[i] = d[i + 1] = d[i + 2] = 255;
        d[i + 3] = 255;
      }
    }
    ctx.putImageData(id, 0, 0);
    return c;
  }

  function ocrFromImage(imgEl) {
    if (!imgEl || !imgEl.complete || !imgEl.naturalWidth) return Promise.resolve("");
    return loadTesseract().then(function (Tesseract) {
      var canvas = preprocessCanvas(imgEl);
      return Tesseract.recognize(canvas, "chi_tra", { logger: function () {} }).then(function (res) {
        return cleanOcr(res.data.text);
      });
    }).catch(function () { return ""; });
  }

  function getOcrText(itemId, imgEl) {
    var cache = getCache();
    if (cache[itemId]) return Promise.resolve(cache[itemId]);
    return ocrFromImage(imgEl).then(function (text) {
      if (text && text.length >= 8) setCache(itemId, text);
      return text;
    });
  }

  function needsImageOcr(it) {
    if (!it || !it.imageUrl) return false;
    if (it.readTextSource === "manual" || it.readTextSource === "seed") return false;
    if (it.source === "種子語錄") return false;
    return true;
  }

  global.TaiyangOcrRead = { getOcrText: getOcrText, needsImageOcr: needsImageOcr };
})(typeof window !== "undefined" ? window : globalThis);
