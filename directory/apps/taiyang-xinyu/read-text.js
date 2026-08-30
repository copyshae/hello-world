/** 太陽心語：朗讀文字（不唸標題，只唸主文＋白話） */
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
    if (it.readText) return it.readText;
    var title = cleanRead(it.title);
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

  global.TaiyangReadText = { speechText: speechText };
})(typeof window !== "undefined" ? window : globalThis);
