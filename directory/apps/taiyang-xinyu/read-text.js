/** 太陽心語：朗讀文字與圖片／卡片上文字一致 */
(function (global) {
  function cleanRead(s) {
    return (s || "")
      .replace(/\s*天圓文化\s*Richestlife\s*/gi, "")
      .replace(/\s*YouTube\s*太陽心語相關影音縮圖\s*/gi, "")
      .replace(/\s+/g, " ")
      .trim();
  }

  function speechText(it) {
    if (!it) return "";
    if (it.readText) return it.readText;
    var title = cleanRead(it.title);
    var text = cleanRead(it.text);
    var plain = cleanRead(it.plain);
    var parts = [];
    if (text) parts.push(text);
    else if (title) parts.push(title);
    if (plain && plain.indexOf("YouTube") < 0) {
      var joined = parts.join("。");
      if (joined.indexOf(plain) < 0) parts.push(plain);
    }
    return parts.filter(Boolean).join("。");
  }

  global.TaiyangReadText = { speechText: speechText };
})(typeof window !== "undefined" ? window : globalThis);
