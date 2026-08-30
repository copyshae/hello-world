/** 太陽心語：朗讀文字（標題唸一次；正文保留完整語句，不裁掉與標題相同字） */
(function (global) {
  function cleanRead(s) {
    return (s || "")
      .replace(/\s*天圓文化\s*Richestlife\s*/gi, "")
      .replace(/\s*YouTube\s*太陽心語相關影音縮圖\s*/gi, "")
      .replace(/^太陽心語[：:]\s*/i, "")
      .replace(/\s+/g, " ")
      .trim();
  }

  function fullBodyFromItem(it) {
    var parts = [];
    var text = cleanRead(it.text || "").replace(/[。]+$/g, "");
    var plain = cleanRead(it.plain || "").replace(/^[。]+/g, "").replace(/[。]+$/g, "");
    if (text) parts.push(text);
    if (plain && plain.indexOf("YouTube") < 0) {
      var joined = parts.join("。");
      if (joined.indexOf(plain) < 0) parts.push(plain);
    }
    var out = parts.filter(Boolean).join("。");
    return out ? out + "。" : "";
  }

  /** 標題另起一段；若正文開頭已是標題，不再重複加標題 */
  function speechWithTitle(title, body) {
    title = cleanRead(title);
    body = cleanRead(body);
    if (!body) return title || "";
    if (!title) return body;
    if (body === title) return title;
    if (body.indexOf(title) === 0) return body;
    return title + "。" + body;
  }

  function speechText(it) {
    if (!it) return "";
    var title = cleanRead(it.title || "");
    if (it.readTextSource === "seed" || it.source === "種子語錄") {
      return speechWithTitle(title, fullBodyFromItem(it));
    }
    if (it.readText && it.readTextSource === "manual") {
      return speechWithTitle(title, it.readText);
    }
    if (it.readText) {
      return speechWithTitle(title, it.readText);
    }
    return speechWithTitle(title, fullBodyFromItem(it));
  }

  function resolveSpeechText(it, imgEl) {
    if (!it) return Promise.resolve("");
    if (it.readTextSource === "manual" || it.readTextSource === "seed") {
      return Promise.resolve(speechText(it));
    }
    if (global.TaiyangOcrRead && global.TaiyangOcrRead.needsImageOcr(it) && imgEl) {
      return global.TaiyangOcrRead.getOcrText(it.id, imgEl).then(function (ocr) {
        if (ocr && ocr.length >= 8) return speechWithTitle(cleanRead(it.title || ""), ocr);
        return speechText(it);
      });
    }
    return Promise.resolve(speechText(it));
  }

  global.TaiyangReadText = { speechText: speechText, resolveSpeechText: resolveSpeechText };
})(typeof window !== "undefined" ? window : globalThis);
