/** 太陽心語：朗讀文字（不唸標題；原圖項目可 OCR） */
(function (global) {
  function cleanRead(s) {
    return (s || "")
      .replace(/\s*天圓文化\s*Richestlife\s*/gi, "")
      .replace(/\s*YouTube\s*太陽心語相關影音縮圖\s*/gi, "")
      .replace(/\s+/g, " ")
      .trim();
  }

  function stripShortTitlePrefix(title, text) {
    title = cleanRead(title);
    text = cleanRead(text);
    if (!title || !text || text.indexOf(title) !== 0) return text;
    if (title.indexOf("，") >= 0 || title.indexOf("；") >= 0) return text;
    var rest = text.slice(title.length);
    if (rest.charAt(0) === "，" || rest.charAt(0) === ",") {
      var body = rest.replace(/^[，,、。 ]+/, "");
      return body || text;
    }
    return text;
  }

  function speechText(it) {
    if (!it) return "";
    if (it.readText && it.readTextSource === "manual") return it.readText;
    if (it.readText && (it.readTextSource === "seed" || it.source === "種子語錄")) return it.readText;
    if (it.readText) return it.readText;
    var text = stripShortTitlePrefix(it.title, it.text);
    var plain = cleanRead(it.plain);
    var parts = [];
    if (text) parts.push(text);
    if (plain && plain.indexOf("YouTube") < 0) {
      var joined = parts.join("。");
      if (joined.indexOf(plain) < 0) parts.push(plain);
    }
    return parts.filter(Boolean).join("。");
  }

  function resolveSpeechText(it, imgEl) {
    if (!it) return Promise.resolve("");
    if (it.readTextSource === "manual" || it.readTextSource === "seed") {
      return Promise.resolve(it.readText || speechText(it));
    }
    if (global.TaiyangOcrRead && global.TaiyangOcrRead.needsImageOcr(it) && imgEl) {
      return global.TaiyangOcrRead.getOcrText(it.id, imgEl).then(function (ocr) {
        if (ocr && ocr.length >= 8) return ocr;
        return speechText(it);
      });
    }
    return Promise.resolve(speechText(it));
  }

  global.TaiyangReadText = { speechText: speechText, resolveSpeechText: resolveSpeechText };
})(typeof window !== "undefined" ? window : globalThis);
