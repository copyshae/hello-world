/* 語音讀誦：男聲／女聲多選（habits-7／daily-14／life-desk 共用偏好） */
(function (global) {
  const TTS_PREF_KEY = "tts-voice-pref-v3";
  const TTS_PREF_KEY_LEGACY = "tts-voice-pref-v2";
  const TTS_PREF_KEY_LEGACY2 = "tts-voice-pref-v1";

  // 常見中文／系統語音名稱線索（男聲線索放寬，避免漏掉真正男聲）
  const FEMALE_HINT = /female|woman|girl|女聲|女|mei[-\s]?jia|ting[-\s]?ting|hsiaochen|hsiaoyu|hsiao[-\s]?chen|hsiao[-\s]?yu|xiaoxiao|xiaoyi|xiaoyan|xiaochen|hanhan|yaoyao|huihui|tracy|susan|linda|karen|zira|jenny|aria|sonia|nanami|kyoko|yuna|heami|meijia|tingting|zhiyu|xiaomeng|xiaoqiu|hannah|catherine|sin[-\s]?ji|hiu[-\s]?maan|xiaomiao|xiaohan|晓晓|曉曉|曉雨|美佳|婷婷|曉臻|晓萱/i;
  const MALE_HINT = /male|man|boy|男聲|男|yunjhe|yun[-\s]?jhe|yunyang|yunjian|yunjie|yunxi|yunhao|yunye|yuncheng|yunfeng|kangkang|zhiwei|li[-\s]?mu|云哲|雲哲|云扬|雲揚|云健|雲健|康康|志伟|志偉|晓东|曉東|雲傑|云杰|yunye|hsiaoyu male|taiwanese male|chinese male/i;
  const NICE_FEMALE = [/hsiaochen/i, /mei[-\s]?jia/i, /ting[-\s]?ting/i, /hsiaoyu/i, /xiaoxiao/i];
  const NICE_MALE = [/yunjhe/i, /yunyang/i, /yunjian/i, /yunjie/i, /zhiwei/i, /kangkang/i, /yunxi/i, /yunfeng/i];

  function loadTtsPref() {
    try {
      const raw = localStorage.getItem(TTS_PREF_KEY)
        || localStorage.getItem(TTS_PREF_KEY_LEGACY)
        || localStorage.getItem(TTS_PREF_KEY_LEGACY2);
      if (!raw) return { gender: "F", choiceId: "", voiceURI: "", voiceName: "", pitch: 1, rate: 0.95 };
      const p = JSON.parse(raw);
      const gender = (p.gender === "M" || p.gender === "all") ? p.gender : "F";
      return {
        gender: gender,
        choiceId: p.choiceId || "",
        voiceURI: p.voiceURI || "",
        voiceName: p.voiceName || "",
        pitch: Number(p.pitch) > 0 ? Number(p.pitch) : 1,
        rate: Number(p.rate) > 0 ? Number(p.rate) : 0.95
      };
    } catch (e) {
      return { gender: "F", choiceId: "", voiceURI: "", voiceName: "", pitch: 1, rate: 0.95 };
    }
  }

  function saveTtsPref(pref) {
    try { localStorage.setItem(TTS_PREF_KEY, JSON.stringify(pref)); } catch (e) {}
  }

  function guessGender(voice) {
    const s = (voice.name || "") + " " + (voice.lang || "") + " " + (voice.voiceURI || "");
    // 先判男再判女，避免把 Yun* 等誤判
    if (MALE_HINT.test(s)) return "M";
    if (FEMALE_HINT.test(s)) return "F";
    return "U";
  }

  function regionLabel(voice) {
    const s = (voice.lang || "") + " " + (voice.name || "");
    if (/zh-TW|zh_TW|Taiwan|臺灣|台灣|國語.*臺/i.test(s)) return "台灣";
    if (/zh-HK|yue|Cantonese|香港|粵/i.test(s)) return "香港";
    if (/zh-CN|zh_CN|China|普通話|大陆|大陸/i.test(s)) return "大陸";
    return voice.lang || "";
  }

  function listZhVoices() {
    try {
      const voices = (global.speechSynthesis && global.speechSynthesis.getVoices()) || [];
      return voices.filter(function (v) {
        return /zh|cmn|yue|chinese|中文|國語|普通话|粤|華語|华语/i.test((v.lang || "") + " " + (v.name || ""));
      });
    } catch (e) {
      return [];
    }
  }

  function voiceScore(voice, preferGender) {
    let score = 0;
    const g = guessGender(voice);
    const s = (voice.name || "") + " " + (voice.lang || "");
    if (/zh-TW|Taiwan|臺灣|台灣/i.test(s)) score += 50;
    else if (/zh-HK|香港/i.test(s)) score += 20;
    else if (/zh-CN|CN/i.test(s)) score += 10;
    if (preferGender === "F" && g === "F") score += 40;
    if (preferGender === "M" && g === "M") score += 40;
    if (preferGender === "F") {
      NICE_FEMALE.forEach(function (re, i) { if (re.test(s)) score += 30 - i; });
    }
    if (preferGender === "M") {
      NICE_MALE.forEach(function (re, i) { if (re.test(s)) score += 30 - i; });
    }
    if (/Natural|Online|Premium|Neural/i.test(s)) score += 8;
    return score;
  }

  function sortZh(preferGender) {
    const prefer = preferGender === "all" ? "F" : preferGender;
    return listZhVoices().slice().sort(function (a, b) {
      return voiceScore(b, prefer) - voiceScore(a, prefer);
    });
  }

  function isIOS() {
    try {
      return /iPad|iPhone|iPod/.test(navigator.userAgent)
        || (navigator.platform === "MacIntel" && navigator.maxTouchPoints > 1);
    } catch (e) { return false; }
  }

  function makeChoice(id, voice, pitch, gender, label, synthetic, rate) {
    return {
      id: id,
      voice: voice,
      pitch: pitch,
      rate: (typeof rate === "number" && rate > 0) ? rate : 0.95,
      gender: gender,
      label: label,
      synthetic: !!synthetic
    };
  }

  function nativeLabel(voice) {
    const g = guessGender(voice);
    const gText = g === "F" ? "女聲" : g === "M" ? "男聲（系統原音）" : "未標示";
    const reg = regionLabel(voice);
    return gText + (reg ? "・" + reg : "") + "｜" + voice.name;
  }

  function pickMaleBaseVoice(zh) {
    // iPhone 只有美佳／婷婷／善怡等女聲；選一支當男聲模式基底即可，避免清單重複一堆
    const prefer = [/mei/i, /美佳/i, /ting/i, /婷婷/i, /google/i, /hsiao/i, /xiao/i];
    for (let i = 0; i < prefer.length; i++) {
      const hit = zh.find(function (v) { return prefer[i].test((v.name || "") + (v.voiceURI || "")); });
      if (hit) return hit;
    }
    return zh[0] || null;
  }

  function listVoiceChoices(gender) {
    const zh = sortZh(gender === "all" ? "F" : gender);
    const choices = [];
    const seen = {};
    const ios = isIOS();

    function pushChoice(c) {
      if (!c || !c.id || seen[c.id]) return;
      seen[c.id] = true;
      choices.push(c);
    }

    function addNative(v, pitch, rate) {
      const g = guessGender(v);
      pushChoice(makeChoice(
        "native:" + (v.voiceURI || v.name),
        v,
        typeof pitch === "number" ? pitch : 1,
        g,
        nativeLabel(v),
        false,
        typeof rate === "number" ? rate : 0.95
      ));
    }

    function addMaleModes(bases) {
      // iOS 對 pitch 支援弱，用更極端參數；並只列出少數選項避免「美佳／婷婷」刷一排
      const presets = ios ? [
        { pitch: 0.2, rate: 0.82, tag: "超低沉（建議）", id: "ios-deepest" },
        { pitch: 0.35, rate: 0.84, tag: "明顯低沉", id: "ios-deep" },
        { pitch: 0.5, rate: 0.88, tag: "沉穩", id: "ios-steady" }
      ] : [
        { pitch: 0.42, rate: 0.85, tag: "明顯低沉（建議）", id: "deep" },
        { pitch: 0.28, rate: 0.82, tag: "超低沉", id: "deeper" },
        { pitch: 0.55, rate: 0.88, tag: "沉穩", id: "steady" }
      ];
      const list = ios
        ? [pickMaleBaseVoice(bases)].filter(Boolean)
        : bases.slice(0, 3);
      list.forEach(function (v) {
        const key = v.voiceURI || v.name;
        presets.forEach(function (p) {
          const suffix = ios ? "" : ("｜" + v.name);
          pushChoice(makeChoice(
            "male-mode:" + p.id + ":" + p.pitch + ":" + key,
            v,
            p.pitch,
            "M",
            "男聲模式・" + p.tag + suffix,
            true,
            p.rate
          ));
        });
      });
    }

    function addFemaleEffects(bases) {
      bases.slice(0, ios ? 1 : 3).forEach(function (v) {
        const key = v.voiceURI || v.name;
        pushChoice(makeChoice(
          "effect-f:1.12:" + key,
          v,
          1.12,
          "F",
          "女聲效果・柔和｜" + v.name,
          true,
          0.95
        ));
      });
    }

    if (!zh.length) return choices;

    if (gender === "M") {
      zh.filter(function (v) { return guessGender(v) === "M"; }).forEach(function (v) {
        addNative(v, 1, 0.95);
      });
      addMaleModes(zh);
      // iPhone 不列出「原音美佳」以免誤選又變女聲
      if (!ios) {
        zh.filter(function (v) { return guessGender(v) === "U"; }).forEach(function (v) {
          pushChoice(makeChoice(
            "native-u:" + (v.voiceURI || v.name),
            v,
            1,
            "U",
            "原音（可能偏女聲）｜" + v.name,
            false,
            0.95
          ));
        });
      }
    } else if (gender === "F") {
      zh.filter(function (v) { return guessGender(v) === "F"; }).forEach(function (v) { addNative(v); });
      zh.filter(function (v) { return guessGender(v) === "U"; }).forEach(function (v) { addNative(v); });
      if (!choices.length) zh.forEach(function (v) { addNative(v); });
      addFemaleEffects(zh);
    } else {
      zh.forEach(function (v) { addNative(v); });
      addMaleModes(zh);
      addFemaleEffects(zh);
    }

    return choices;
  }

  function isWeakMaleChoice(c) {
    if (!c) return true;
    if (c.synthetic && c.gender === "M") return false;
    if (!c.synthetic && c.voice && guessGender(c.voice) === "M") return false;
    // 舊版 effect-m / 美佳原音 都算弱男聲
    if (/effect-m:|native-u:|native:/i.test(c.id || "") && guessGender(c.voice) !== "M") return true;
    return true;
  }

  function purgeLegacyMalePref() {
    try {
      const pref = loadTtsPref();
      if (pref.gender !== "M") return;
      const weakId = /effect-m:|^native:|native-u:/i.test(pref.choiceId || "");
      const weakName = /美佳|婷婷|善怡|Mei|Ting|Sin-ji|Shan/i.test(pref.voiceName || "");
      if (weakId || weakName || !pref.choiceId || !/male-mode:/.test(pref.choiceId || "")) {
        // 若不是 male-mode，清掉讓系統重選超低沉
        if (!/male-mode:/.test(pref.choiceId || "")) {
          pref.choiceId = "";
          pref.voiceURI = "";
          pref.voiceName = "";
          pref.pitch = isIOS() ? 0.2 : 0.42;
          pref.rate = isIOS() ? 0.82 : 0.85;
          saveTtsPref(pref);
        }
      }
    } catch (e) {}
  }

  function resolveSelectedChoice() {
    purgeLegacyMalePref();
    const pref = loadTtsPref();
    const list = listVoiceChoices(pref.gender);
    if (!list.length) return null;

    if (pref.choiceId) {
      const byId = list.find(function (c) { return c.id === pref.choiceId; });
      if (byId && !(pref.gender === "M" && isWeakMaleChoice(byId))) return byId;
    }

    if (pref.gender === "M") {
      return list.find(function (c) { return c.gender === "M" && !c.synthetic; })
        || list.find(function (c) { return c.synthetic && c.gender === "M" && /建議|超低沉/.test(c.label); })
        || list.find(function (c) { return c.synthetic && c.gender === "M"; })
        || list[0];
    }

    if (pref.voiceURI || pref.voiceName) {
      const byVoice = list.find(function (c) {
        return (!c.synthetic) && (
          (pref.voiceURI && c.voice.voiceURI === pref.voiceURI) ||
          (pref.voiceName && c.voice.name === pref.voiceName)
        );
      });
      if (byVoice) return byVoice;
    }
    return list[0];
  }

  function resolveSelectedVoice() {
    const c = resolveSelectedChoice();
    return c ? c.voice : null;
  }

  function getSpeakSettings() {
    const pref = loadTtsPref();
    const c = resolveSelectedChoice();
    const iosDeepPitch = isIOS() ? 0.2 : 0.42;
    const iosDeepRate = isIOS() ? 0.82 : 0.85;
    if (!c) {
      return {
        voice: null,
        pitch: pref.gender === "M" ? iosDeepPitch : 1,
        rate: pref.gender === "M" ? iosDeepRate : 0.95,
        lang: "zh-TW"
      };
    }
    let pitch = (typeof c.pitch === "number") ? c.pitch : 1;
    let rate = (typeof c.rate === "number") ? c.rate : 0.95;
    if (pref.gender === "M" && isWeakMaleChoice(c)) {
      pitch = iosDeepPitch;
      rate = iosDeepRate;
    }
    // iOS 有時忽略輕微 pitch；男聲模式再保險壓一次下限
    if (pref.gender === "M" && isIOS() && pitch > 0.35) pitch = 0.2;
    return {
      voice: c.voice,
      pitch: pitch,
      rate: rate,
      lang: (c.voice && c.voice.lang) || "zh-TW",
      label: c.label,
      synthetic: c.synthetic || (pref.gender === "M" && isWeakMaleChoice(c))
    };
  }

  function updateVoiceHint(gender, choices) {
    const hint = document.getElementById("ttsVoiceHint");
    if (!hint) return;
    const realMale = (choices || []).some(function (c) { return c.gender === "M" && !c.synthetic; });
    if (gender === "M" && isIOS()) {
      hint.textContent = "iPhone 系統中文只有美佳／婷婷／善怡等女聲音色，無法變成真正男聲。請選「男聲模式・超低沉（建議）」並試聽；要真男聲請用電腦 Edge。";
    } else if (gender === "M" && !realMale) {
      hint.textContent = "此裝置多半沒有真正中文男聲。請選「男聲模式・明顯低沉／超低沉」並試聽；電腦 Edge 較容易有系統男聲。";
    } else if (gender === "M") {
      hint.textContent = "已找到系統男聲原音。若仍偏尖，可改選「男聲模式」。";
    } else {
      hint.textContent = "可選多種男聲／女聲。iPhone 選男聲時請用「男聲模式」。";
    }
  }

  function fillVoiceSelectors() {
    const genderEl = document.getElementById("ttsGender");
    const voiceEl = document.getElementById("ttsVoice");
    if (!genderEl || !voiceEl) return;
    const pref = loadTtsPref();
    genderEl.value = pref.gender || "F";
    const list = listVoiceChoices(genderEl.value);
    voiceEl.innerHTML = "";
    if (!list.length) {
      const opt = document.createElement("option");
      opt.value = "";
      opt.textContent = "（此裝置暫無中文語音，將用系統預設）";
      voiceEl.appendChild(opt);
      updateVoiceHint(genderEl.value, list);
      return;
    }
    list.forEach(function (c) {
      const opt = document.createElement("option");
      opt.value = c.id;
      opt.textContent = c.label;
      voiceEl.appendChild(opt);
    });
    const sel = resolveSelectedChoice();
    if (sel) voiceEl.value = sel.id;
    updateVoiceHint(genderEl.value, list);
  }

  function applyFromUI() {
    const genderEl = document.getElementById("ttsGender");
    const voiceEl = document.getElementById("ttsVoice");
    if (!genderEl || !voiceEl) return;
    const list = listVoiceChoices(genderEl.value);
    const chosen = list.find(function (c) { return c.id === voiceEl.value; }) || list[0] || null;
    saveTtsPref({
      gender: genderEl.value,
      choiceId: chosen ? chosen.id : "",
      voiceURI: chosen && chosen.voice ? (chosen.voice.voiceURI || "") : "",
      voiceName: chosen && chosen.voice ? chosen.voice.name : "",
      pitch: chosen ? chosen.pitch : 1,
      rate: chosen ? chosen.rate : 0.95
    });
  }

  function bindVoicePicker(options) {
    const genderEl = document.getElementById("ttsGender");
    const voiceEl = document.getElementById("ttsVoice");
    const previewBtn = document.getElementById("ttsPreview");
    if (!genderEl || !voiceEl) return;

    genderEl.addEventListener("change", function () {
      // 切到男聲時清掉舊的女聲原音偏好，改走男聲模式預設
      saveTtsPref({
        gender: genderEl.value,
        choiceId: "",
        voiceURI: "",
        voiceName: "",
        pitch: genderEl.value === "M" ? 0.48 : 1,
        rate: genderEl.value === "M" ? 0.86 : 0.95
      });
      fillVoiceSelectors();
      applyFromUI();
    });
    voiceEl.addEventListener("change", applyFromUI);

    if (previewBtn) {
      previewBtn.addEventListener("click", function () {
        applyFromUI();
        const settings = getSpeakSettings();
        let say = "您好，這是目前選擇的讀誦聲音。以身心靈提升、靈命持續成長為首要。";
        if (settings.synthetic && settings.pitch < 1) {
          say = "您好，這是男聲模式讀誦。以身心靈提升、靈命持續成長為首要。";
        } else if (settings.synthetic && settings.pitch > 1) {
          say = "您好，這是女聲效果讀誦。以身心靈提升、靈命持續成長為首要。";
        }
        if (options && typeof options.speak === "function") options.speak(say);
        else if (typeof global.speakText === "function") global.speakText(say);
      });
    }

    fillVoiceSelectors();
    notifySpeakStatus({ reason: "init" });
    if (global.speechSynthesis) {
      global.speechSynthesis.addEventListener("voiceschanged", function () {
        fillVoiceSelectors();
      });
      setTimeout(fillVoiceSelectors, 250);
      setTimeout(fillVoiceSelectors, 1000);
      setTimeout(fillVoiceSelectors, 2500);
    }
  }

  /* ========== 分段讀誦＋暫停／繼續／取消 ========== */
  let speakSession = 0;
  let speakChunks = [];
  let speakIndex = 0;
  let speakPaused = false;
  let speakActive = false;
  let speakKeepAliveTimer = null;
  let statusListeners = [];

  function notifySpeakStatus(extra) {
    const st = Object.assign({
      active: speakActive,
      paused: speakPaused,
      index: speakIndex,
      total: speakChunks.length,
      session: speakSession
    }, extra || {});
    statusListeners.forEach(function (fn) {
      try { fn(st); } catch (e) {}
    });
    // 更新畫面上常見狀態文字
    try {
      document.querySelectorAll("[data-tts-status]").forEach(function (el) {
        if (!speakActive) {
          el.textContent = "";
          el.hidden = true;
          return;
        }
        el.hidden = false;
        const n = speakChunks.length ? (speakIndex + 1) : 0;
        const total = speakChunks.length;
        el.textContent = speakPaused
          ? ("已暫停（" + n + "／" + total + " 段）— 可按繼續或取消")
          : ("讀誦中（" + n + "／" + total + " 段）— 可隨時暫停或取消");
      });
    } catch (e) {}
    // 同步按鈕狀態
    try {
      document.querySelectorAll("[data-tts-pause]").forEach(function (btn) {
        btn.disabled = !speakActive;
        btn.textContent = speakPaused ? "▶ 繼續" : "⏸ 暫停";
      });
      document.querySelectorAll("[data-tts-stop]").forEach(function (btn) {
        btn.disabled = !speakActive;
      });
    } catch (e) {}
  }

  function onSpeakStatus(fn) {
    if (typeof fn === "function") statusListeners.push(fn);
  }

  function clearKeepAlive() {
    if (speakKeepAliveTimer) {
      clearInterval(speakKeepAliveTimer);
      speakKeepAliveTimer = null;
    }
  }

  function startKeepAlive() {
    clearKeepAlive();
    // Chrome 長語音偶發靜默中斷：短暫 pause/resume 保活
    speakKeepAliveTimer = setInterval(function () {
      if (!speakActive || speakPaused) return;
      try {
        if (global.speechSynthesis && global.speechSynthesis.speaking) {
          global.speechSynthesis.pause();
          global.speechSynthesis.resume();
        }
      } catch (e) {}
    }, 12000);
  }

  function splitSpeechChunks(text, maxLen) {
    maxLen = maxLen || 120;
    const raw = String(text || "").replace(/\s+/g, " ").trim();
    if (!raw) return [];
    const parts = [];
    let cur = "";
    for (let i = 0; i < raw.length; i++) {
      cur += raw[i];
      const ch = raw[i];
      const punct = "。！？；!?;，,、：:";
      if (punct.indexOf(ch) >= 0 || cur.length >= maxLen) {
        const t = cur.trim();
        if (t) parts.push(t);
        cur = "";
      }
    }
    if (cur.trim()) parts.push(cur.trim());
    // 合併過短片段，避免斷得太碎
    const merged = [];
    parts.forEach(function (p) {
      if (merged.length && (merged[merged.length - 1].length + p.length) < Math.floor(maxLen * 0.55)) {
        merged[merged.length - 1] += p;
      } else {
        merged.push(p);
      }
    });
    return merged;
  }

  function stopSpeakQueue() {
    speakSession += 1;
    speakChunks = [];
    speakIndex = 0;
    speakPaused = false;
    speakActive = false;
    clearKeepAlive();
    try { global.speechSynthesis && global.speechSynthesis.cancel(); } catch (e) {}
    notifySpeakStatus({ reason: "stop" });
  }

  function pauseSpeakQueue() {
    if (!speakActive || speakPaused) return;
    speakPaused = true;
    try { global.speechSynthesis && global.speechSynthesis.pause(); } catch (e) {}
    // 部分瀏覽器 pause 不可靠：取消目前段，稍後從同段繼續
    try {
      if (global.speechSynthesis && !global.speechSynthesis.paused) {
        global.speechSynthesis.cancel();
      }
    } catch (e) {}
    notifySpeakStatus({ reason: "pause" });
  }

  function resumeSpeakQueue() {
    if (!speakActive || !speakPaused) return;
    speakPaused = false;
    notifySpeakStatus({ reason: "resume" });
    try {
      if (global.speechSynthesis && global.speechSynthesis.paused) {
        global.speechSynthesis.resume();
        return;
      }
    } catch (e) {}
    // 從目前段落重播
    speakNextChunk(speakSession);
  }

  function togglePauseSpeakQueue() {
    if (!speakActive) return;
    if (speakPaused) resumeSpeakQueue();
    else pauseSpeakQueue();
  }

  function makeUtterance(chunk, settings, opts) {
    const u = new SpeechSynthesisUtterance(String(chunk || ""));
    u.rate = (opts && opts.rate) || settings.rate || 0.95;
    u.pitch = (opts && opts.pitch) || settings.pitch || 1;
    if (settings.voice) {
      u.voice = settings.voice;
      u.lang = settings.voice.lang || settings.lang || "zh-TW";
    } else {
      u.lang = settings.lang || "zh-TW";
    }
    return u;
  }

  function speakNextChunk(sessionId) {
    if (sessionId !== speakSession) return;
    if (speakPaused) return;
    if (speakIndex >= speakChunks.length) {
      speakActive = false;
      speakPaused = false;
      clearKeepAlive();
      notifySpeakStatus({ reason: "done" });
      return;
    }
    const settings = getSpeakSettings();
    const chunk = speakChunks[speakIndex];
    const u = makeUtterance(chunk, settings, {});
    u.onend = function () {
      if (sessionId !== speakSession) return;
      if (speakPaused) return;
      speakIndex += 1;
      notifySpeakStatus({ reason: "progress" });
      // 小間隔，讓取消／暫停更容易插入
      setTimeout(function () { speakNextChunk(sessionId); }, 40);
    };
    u.onerror = function () {
      if (sessionId !== speakSession) return;
      if (speakPaused) return;
      speakIndex += 1;
      setTimeout(function () { speakNextChunk(sessionId); }, 40);
    };
    try {
      global.speechSynthesis.speak(u);
    } catch (e) {
      speakIndex += 1;
      setTimeout(function () { speakNextChunk(sessionId); }, 40);
    }
    notifySpeakStatus({ reason: "speaking" });
  }

  function speakQueued(text, opts) {
    if (!global.speechSynthesis) {
      alert("此瀏覽器不支援語音讀誦，請用 Chrome／Edge／Safari。");
      return false;
    }
    stopSpeakQueue();
    const chunks = splitSpeechChunks(text, (opts && opts.maxLen) || 120);
    if (!chunks.length) return false;
    speakSession += 1;
    const sessionId = speakSession;
    speakChunks = chunks;
    speakIndex = 0;
    speakPaused = false;
    speakActive = true;
    startKeepAlive();
    notifySpeakStatus({ reason: "start" });
    speakNextChunk(sessionId);
    return true;
  }

  function getSpeakState() {
    return {
      active: speakActive,
      paused: speakPaused,
      index: speakIndex,
      total: speakChunks.length
    };
  }

  global.TtsVoices = {
    loadTtsPref: loadTtsPref,
    saveTtsPref: saveTtsPref,
    pickZhVoice: resolveSelectedVoice,
    resolveSelectedVoice: resolveSelectedVoice,
    resolveSelectedChoice: resolveSelectedChoice,
    getSpeakSettings: getSpeakSettings,
    fillVoiceSelectors: fillVoiceSelectors,
    bindVoicePicker: bindVoicePicker,
    listZhVoices: listZhVoices,
    listVoiceChoices: listVoiceChoices,
    splitSpeechChunks: splitSpeechChunks,
    speakQueued: speakQueued,
    stopSpeakQueue: stopSpeakQueue,
    pauseSpeakQueue: pauseSpeakQueue,
    resumeSpeakQueue: resumeSpeakQueue,
    togglePauseSpeakQueue: togglePauseSpeakQueue,
    getSpeakState: getSpeakState,
    onSpeakStatus: onSpeakStatus
  };
})(typeof window !== "undefined" ? window : this);
