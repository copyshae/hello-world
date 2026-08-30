/** 太陽心語：朗讀文字（種子卡片唸標題＋主文；原圖只唸圖上內容） */
(function (global) {
  function cleanRead(s) {
    return (s || "")
      .replace(/\s*天圓文化\s*Richestlife\s*/gi, "")
      .replace(/\s*YouTube\s*太陽心語相關影音縮圖\s*/gi, "")
      .replace(/^太陽心語[：:]\s*/i, "")
      .replace(/\s+/g, " ")
      .trim();
  }

  function isWebOriginalImage(it) {
    if (!it) return false;
    if (it.readTextSource === "manual") return true;
    return it.source === "網路搜尋" && !!it.imageUrl;
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

  function speechWithTitle(title, body) {
    title = cleanRead(title);
    body = cleanRead(body);
    if (!body) return title || "";
    if (!title) return body;
    if (body === title) return title;
    if (body.indexOf(title) === 0) return body;
    return title + "。" + body;
  }

  function imageOnlySpeech(it) {
    if (it.readText && it.readTextSource === "manual") return cleanRead(it.readText);
    return "";
  }

  function speechText(it) {
    if (!it) return "";
    if (isWebOriginalImage(it)) return imageOnlySpeech(it);
    if (it.readTextSource === "seed" || it.source === "種子語錄") {
      return speechWithTitle(cleanRead(it.title || ""), fullBodyFromItem(it));
    }
    if (it.readTextSource === "filename") return "";
    if (it.readTextSource === "youtube" && it.readText) return cleanRead(it.readText);
    if (it.readText) return cleanRead(it.readText);
    return speechWithTitle(cleanRead(it.title || ""), fullBodyFromItem(it));
  }

  function displayQuote(it) {
    if (!it) return { title: "太陽心語", text: "", plain: "" };
    if (it.readTextSource === "seed" || it.source === "種子語錄") {
      return { title: it.title || "太陽心語", text: it.text || it.readText || "", plain: it.plain || "" };
    }
    if (isWebOriginalImage(it)) {
      return {
        title: "太陽心語",
        text: (it.readTextSource === "manual" && it.readText) ? it.readText : "",
        plain: ""
      };
    }
    if (it.readTextSource === "youtube" && it.readText) {
      return { title: it.title || "太陽心語", text: it.readText, plain: "" };
    }
    return { title: it.title || "太陽心語", text: it.text || "", plain: it.plain || "" };
  }

  function resolveSpeechText(it, imgEl) {
    if (!it) return Promise.resolve("");
    if (it.readTextSource === "manual") return Promise.resolve(imageOnlySpeech(it));
    if (it.readTextSource === "seed") return Promise.resolve(speechText(it));
    if (global.TaiyangOcrRead && global.TaiyangOcrRead.needsImageOcr(it) && imgEl) {
      return global.TaiyangOcrRead.getOcrText(it.id, imgEl).then(function (ocr) {
        if (ocr && ocr.length >= 8) return cleanRead(ocr);
        return speechText(it);
      });
    }
    return Promise.resolve(speechText(it));
  }

  global.TaiyangReadText = {
    speechText: speechText,
    resolveSpeechText: resolveSpeechText,
    displayQuote: displayQuote,
    isWebOriginalImage: isWebOriginalImage
  };
})(typeof window !== "undefined" ? window : globalThis);
