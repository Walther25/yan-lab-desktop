/*
 * Yan Lab · Desktop archive
 * Hace que la vista principal (COLUMN 0X / 05, flechas ↑ ↓, INTERNAL DATABASE,
 * ACCESS FILE) recorra PC settings · Clients · Apps · Games · Documents en lugar
 * de los 40 archivos de lore. El 3D, las animaciones y la navegación siguen
 * siendo los del fondo original: solo se reemplazan los datos que se muestran,
 * a través de los enganches de window.rhineArchiveOverride (ver patch_bundle.py).
 */
(function () {
  "use strict";

  var REFRESH_MS = 15000;
  var ROWS_KEY = "rhine-desk-rows";

  // ---- Utilidades --------------------------------------------------------
  function cfg() {
    var c = window.rhineBridgeConfig;
    return c && c.token && c.port ? c : null;
  }
  function api(path, params, init) {
    var c = cfg();
    var q = new URLSearchParams(params || {});
    q.set("token", c.token);
    var ctrl = typeof AbortController === "function" ? new AbortController() : null;
    var timer = ctrl ? setTimeout(function () { ctrl.abort(); }, 5000) : 0;
    var opts = Object.assign({ cache: "no-store" }, init || {});
    if (ctrl) opts.signal = ctrl.signal;
    return fetch("http://127.0.0.1:" + c.port + path + "?" + q.toString(), opts)
      .then(function (r) { return r.json(); })
      .finally(function () { clearTimeout(timer); });
  }
  function esc(s) {
    return String(s == null ? "" : s).replace(/[&<>"']/g, function (ch) {
      return { "&": "&amp;", "<": "&lt;", ">": "&gt;", '"': "&quot;", "'": "&#39;" }[ch];
    });
  }
  function key(name) {
    return String(name).normalize("NFD").replace(/[̀-ͯ]/g, "").toLowerCase().replace(/[^a-z0-9]/g, "");
  }
  function pad(n, w) { return String(n).padStart(w || 2, "0"); }
  function fmtDate(iso) {
    var d = new Date(iso);
    if (isNaN(d)) return "—";
    return d.getFullYear() + "." + pad(d.getMonth() + 1) + "." + pad(d.getDate()) + " " + pad(d.getHours()) + ":" + pad(d.getMinutes());
  }
  function fmtSize(b) {
    if (b == null) return "";
    var u = ["B", "KB", "MB", "GB", "TB"], i = 0, v = b;
    while (v >= 1024 && i < u.length - 1) { v /= 1024; i++; }
    return (i === 0 ? v : v.toFixed(v < 10 ? 1 : 0)) + " " + u[i];
  }
  function displayName(it) {
    if (it.launch && /^\.(lnk|url|appref-ms)$/.test(it.ext)) return it.name.slice(0, -it.ext.length);
    return it.name;
  }
  function steamId(it) {
    var m = /^steam:\/\/rungameid\/(\d+)/i.exec(it.url || "");
    return m ? m[1] : "";
  }
  function typeLabel(it) {
    if (it.dir) return "FOLDER";
    var e = it.ext, t = (it.target || "").toLowerCase();
    if (e === ".url") {
      if (t === "steam") return "STEAM SHORTCUT";
      if (t.indexOf("epicgames") >= 0) return "EPIC GAMES SHORTCUT";
      if (t === "http" || t === "https") return "WEB LINK";
      return "URL SHORTCUT";
    }
    if (e === ".lnk") return "APP SHORTCUT";
    if (it.launch && e === ".exe") return "PROGRAM";
    if (it.launch && e === ".jar") return "JAVA PROGRAM";
    if (it.blocked) return (e ? e.slice(1).toUpperCase() + " · " : "") + "EXPLORER ONLY";
    if (it.kind === "pdf") return "PDF DOCUMENT";
    if (/^\.(docx?|docm|dotx?|odt|rtf)$/.test(e)) return "WORD DOCUMENT";
    if (/^\.(xlsx?|xlsm|xlsb|xltx?|csv|ods)$/.test(e)) return "SPREADSHEET";
    if (/^\.(pptx?|pptm|potx|odp)$/.test(e)) return "PRESENTATION";
    if (it.kind === "office") return "OFFICE FILE";
    if (it.kind === "image") return "IMAGE";
    return e ? e.slice(1).toUpperCase() + " FILE" : "FILE";
  }
  function typeName(it) {
    if (it.dir) return "Folder";
    var e = it.ext;
    if (e === ".url") return steamId(it) ? "Steam shortcut" : (it.target === "http" || it.target === "https") ? "Web link" : "URL shortcut";
    if (e === ".lnk") return "Shortcut";
    if (e === ".exe") return "Program (.exe)";
    if (e === ".jar") return "Java program (.jar)";
    if (it.kind === "pdf") return "PDF document";
    if (/^\.(docx?|docm|dotx?|odt|rtf)$/.test(e)) return "Word document";
    if (/^\.(xlsx?|xlsm|xlsb|xltx?|csv|ods)$/.test(e)) return "Spreadsheet";
    if (/^\.(pptx?|pptm|potx|odp)$/.test(e)) return "Presentation";
    if (it.kind === "image") return "Image";
    return e ? e.slice(1).toUpperCase() + " file" : "File";
  }

  // ---- Estado ------------------------------------------------------------
  var columns = null;          // [{id,label,launch,items:[…]}] en el orden de las 5 columnas
  var rows = {};               // fila elegida por columna (nuestra)
  var prevOrig = {};           // última fila original por columna (para seguir arrastres y clics en el 3D)
  var suspended = false;       // true mientras se ve un archivo de lore abierto desde ARCHIVE INDEX
  var detailOn = false;
  var current = null;          // {lane, row, item, col}
  var raw = "";
  try { rows = JSON.parse(localStorage.getItem(ROWS_KEY) || "{}") || {}; } catch (e) { rows = {}; }
  function saveRows() { try { localStorage.setItem(ROWS_KEY, JSON.stringify(rows)); } catch (e) { /* nada */ } }

  function activeFlag() {
    var st = document.getElementById("stage");
    if (st) st.dataset.desktopArchive = columns && !suspended ? "on" : "off";
  }

  window.rhineArchiveOverride = {
    view: function (lane, origIdx, e, origTotal) {
      var total = origTotal || 8;
      if (prevOrig[lane] === undefined) prevOrig[lane] = origIdx;
      var dOrig = origIdx - prevOrig[lane];
      prevOrig[lane] = origIdx;
      if (suspended || !columns) return null;
      var col = columns[lane];
      if (!col) return null;
      var n = col.items.length;
      var r = rows[col.id] || 0;
      if (e && e.axis === "row") r += e.direction;
      else if (!(e && e.axis === "lane") && dOrig) {
        var d = ((dOrig % total) + total) % total;
        if (d > total / 2) d -= total;
        r += d;
      }
      r = n ? ((r % n) + n) % n : 0;
      rows[col.id] = r;
      saveRows();
      var it = col.items[r];
      current = { lane: lane, row: r, item: it || null, col: col };
      return {
        title: it ? displayName(it) : "EMPTY FOLDER",
        clearance: it ? typeLabel(it) : "NO RECORDS",
        category: col.label,
        column: col.label,
        code: (lane + 1) * 100 + Math.min(99, r + 1),
        index: n ? r : -1,
        total: n,
        tick: n ? Math.min(total - 1, Math.floor(r * total / n)) : -1
      };
    },
    detail: function () {
      detailOn = false;
      if (suspended || !columns || !current || !current.item) return undefined;
      detailOn = true;
      return renderDetail(current);
    },
    detailActive: function () { return detailOn; }
  };

  // ---- Vista de detalle (ACCESS FILE) -------------------------------------
  function code(c) { return "X-" + pad((c.lane + 1) * 100 + Math.min(99, c.row + 1), 3); }
  function renderDetail(c) {
    var it = c.item, col = c.col;
    var obj = document.getElementById("object-id");
    if (obj) obj.textContent = "NO." + pad((c.lane + 1) * 100 + Math.min(99, c.row + 1), 3);
    var actLabel = it.dir ? "OPEN FOLDER" : it.launch ? "LAUNCH" : it.blocked ? "SHOW IN EXPLORER" : "OPEN FILE";
    var actNote = it.dir ? "Explorer" : it.launch ? typeName(it) : it.blocked ? "Explorer only" : "Default app";
    var sub = it.dir ? (it.count != null ? it.count + (it.count === 1 ? " item" : " items") : "Folder")
      : steamId(it) ? "Steam · App " + steamId(it)
      : it.company || typeName(it);
    var target = it.dir ? col.label + " › " + it.name
      : it.url ? it.url
      : it.targetPath ? it.targetPath.split(/[\\/]/).pop()
      : it.name;
    return '<span data-action="bookmark" hidden></span>' +
      '<div class="detail-kicker"><span>FILE ' + code(c) + "</span><span>" + esc(typeLabel(it)) + "</span></div>" +
      "<h2>" + esc(displayName(it)) + '</h2><div class="detail-title-cn">' + esc(col.label) + "<span>" + esc(sub) + "</span></div>" +
      '<div class="detail-rule"></div>' +
      '<dl class="metadata">' +
      "<div><dt>TYPE</dt><dd>" + esc(typeName(it)) + "</dd></div>" +
      "<div><dt>LOCATION</dt><dd>" + esc(col.label) + "</dd></div>" +
      "<div><dt>TARGET</dt><dd>" + esc(target) + "</dd></div>" +
      "<div><dt>STATUS</dt><dd><i></i>" + (it.blocked ? "Explorer only" : "Ready") + "</dd></div>" +
      "</dl>" +
      '<div class="detail-tabs" role="tablist">' +
      '<button id="tab-overview" class="active" role="tab" aria-controls="tab-panel" aria-selected="true" data-desk-tab="details">01 <span>Details</span></button>' +
      '<button id="tab-notes" role="tab" aria-controls="tab-panel" aria-selected="false" tabindex="-1" data-desk-tab="access">02 <span>Access</span></button>' +
      '<i class="tab-indicator" aria-hidden="true"></i></div>' +
      '<div id="tab-panel" class="tab-panel" role="tabpanel" aria-labelledby="tab-overview">' + panel("details", c) + "</div>" +
      '<div class="detail-actions"><button type="button" class="solid-button" data-desk-open>' + (it.launch ? "▶ " : "↗ ") + actLabel +
      "<span>" + esc(actNote) + "</span></button>" +
      (it.dir || it.blocked ? "" : '<button type="button" class="export-button" data-desk-reveal aria-label="Show in File Explorer">EXPLORER <span>↗</span></button>') +
      "</div>" +
      '<div class="detail-footnote"><span>YAN BRIDGE · LOCAL</span><span>' + pad(c.row + 1, 3) + " / " + pad(col.items.length, 3) + "</span></div>";
  }
  function panel(tab, c) {
    var it = c.item;
    if (tab === "details") {
      var rowsHtml = [];
      function add(k, v) { if (v) rowsHtml.push("<li><span>" + esc(k) + "</span>" + esc(v) + "</li>"); }
      add("Name", it.name);
      add("Program", it.description || it.product);
      add("Publisher", it.company);
      add("Version", it.version);
      add("Steam App ID", steamId(it));
      add("Address", it.url && !steamId(it) ? it.url : "");
      add("Executable", it.targetPath);
      add("Contents", it.dir && it.count != null ? it.count + (it.count === 1 ? " item" : " items") : "");
      add("Size", it.dir ? "" : fmtSize(it.size));
      add("Modified", fmtDate(it.mtime));
      return '<div class="panel-label">DETAILS</div><ol class="research-notes">' + rowsHtml.join("") + "</ol>";
    }
    var how = it.dir ? "Opens this folder in File Explorer."
      : it.launch && it.ext === ".url" ? (steamId(it) ? "Opens the shortcut; Steam starts the game." : "Opens the shortcut with its associated program.")
      : it.launch ? "Runs the program, just like double-clicking its desktop shortcut."
      : it.blocked ? "For safety, this file type is never run from the wallpaper; the button shows it selected in File Explorer."
      : "Opens the file with its default Windows app.";
    return '<div class="panel-label">ACCESS</div><p>' + esc(how) + " Requests go through Yan Bridge, which only answers this computer.</p>";
  }
  function moveIndicator(btn) {
    var ind = document.querySelector("#detail-content .tab-indicator");
    if (ind && btn) ind.style.transform = "translateX(" + btn.offsetLeft + "px) scaleX(" + btn.offsetWidth + ")";
  }
  function selectTab(name) {
    if (!current || !current.item) return;
    var tabs = document.querySelectorAll("#detail-content [data-desk-tab]");
    var activeBtn = null;
    Array.prototype.forEach.call(tabs, function (b) {
      var on = b.getAttribute("data-desk-tab") === name;
      b.classList.toggle("active", on);
      b.setAttribute("aria-selected", String(on));
      b.setAttribute("tabindex", on ? "0" : "-1");
      if (on) activeBtn = b;
    });
    var p = document.getElementById("tab-panel");
    if (p) { p.innerHTML = panel(name, current); if (activeBtn) p.setAttribute("aria-labelledby", activeBtn.id); }
    moveIndicator(activeBtn);
  }

  // ---- Acciones -----------------------------------------------------------
  var noteTimer = 0;
  function note(text) {
    var f = document.querySelector("#detail-content .detail-footnote span");
    if (!f) return;
    f.textContent = text;
    clearTimeout(noteTimer);
    noteTimer = setTimeout(function () { if (f.isConnected) f.textContent = "YAN BRIDGE · LOCAL"; }, 2400);
  }
  function openCurrent(reveal) {
    if (!cfg() || !current || !current.item) return;
    var it = current.item;
    note((reveal ? "SHOWING IN EXPLORER · " : it.launch ? "LAUNCHING · " : "OPENING · ") + displayName(it));
    api("/api/open", {}, {
      method: "POST",
      headers: { "Content-Type": "text/plain" },
      body: JSON.stringify({ root: current.col.id, path: it.path, reveal: !!reveal })
    }).then(function (res) {
      if (!res || !res.ok) note(res && res.error === "missing" ? "FILE NOT FOUND" : "COULD NOT OPEN");
    }).catch(function () { note("YAN BRIDGE OFFLINE"); });
  }

  document.addEventListener("click", function (e) {
    var t = e.target.closest && e.target.closest("button");
    if (!t) return;
    // Abrir un archivo de lore desde ARCHIVE INDEX: mostrar los originales hasta volver.
    if (t.hasAttribute("data-result") && columns) { suspended = true; activeFlag(); return; }
    if (!t.closest("#detail-content")) return;
    if (t.hasAttribute("data-desk-tab")) { e.stopPropagation(); selectTab(t.getAttribute("data-desk-tab")); return; }
    if (t.hasAttribute("data-desk-open")) { e.stopPropagation(); openCurrent(false); return; }
    if (t.hasAttribute("data-desk-reveal")) { e.stopPropagation(); openCurrent(true); return; }
  }, true);

  // Al mostrarse el detalle, posicionar el indicador de pestañas.
  function watchDetail() {
    var dc = document.getElementById("detail-content");
    if (!dc) return false;
    new MutationObserver(function () {
      if (!detailOn) return;
      requestAnimationFrame(function () { moveIndicator(dc.querySelector("[data-desk-tab].active")); });
    }).observe(dc, { childList: true });
    return true;
  }
  // Al volver a la vista de archivo, reactivar las categorías si estaban en pausa.
  function watchStage() {
    var st = document.getElementById("stage");
    if (!st) return false;
    var last = st.dataset.mode;
    new MutationObserver(function () {
      var m = st.dataset.mode;
      if (m === "archive" && last !== "archive" && suspended) {
        suspended = false; activeFlag(); refresh();
      }
      if (m === "detail" && detailOn) {
        requestAnimationFrame(function () { moveIndicator(document.querySelector("#detail-content [data-desk-tab].active")); });
      }
      last = m;
    }).observe(st, { attributes: true, attributeFilter: ["data-mode"] });
    return true;
  }
  // ---- Barra de desplazamiento propia para la ficha de detalle ---------------
  // Wallpaper Engine no entrega a la página el arrastre de la barra nativa ni
  // siempre la rueda; esta barra y el arrastre del contenido usan eventos de
  // puntero (los mismos que hacen girar el modelo 3D).
  function detailScroller() {
    var dc = document.getElementById("detail-content");
    if (!dc || dc.dataset.yanScroll) return !!dc;
    dc.dataset.yanScroll = "1";
    var bar = document.createElement("div");
    bar.className = "docs-scrollbar yan-detail-scrollbar";
    bar.hidden = true;
    bar.innerHTML = '<button type="button" data-yan-step="-1" aria-label="Scroll up">▲</button>' +
      '<div class="docs-track"><i class="docs-thumb"></i></div>' +
      '<button type="button" data-yan-step="1" aria-label="Scroll down">▼</button>';
    document.body.appendChild(bar);
    var track = bar.querySelector(".docs-track"), thumb = bar.querySelector(".docs-thumb");
    var stage = document.getElementById("stage");
    function max() { return Math.max(0, dc.scrollHeight - dc.clientHeight); }
    var last = { left: "", top: "", height: "", th: "", tt: "", hidden: true };
    function setIf(el, key, prop, val) { if (last[key] !== val) { last[key] = val; el.style[prop] = val; } }
    function hide() { if (!last.hidden) { last.hidden = true; bar.hidden = true; } }
    function place() {
      if (!stage || stage.dataset.mode !== "detail") { hide(); return; }
      var m = max();
      if (m <= 1) { hide(); return; }
      var r = dc.getBoundingClientRect();
      if (r.height < 40 || parseFloat(dc.style.opacity || "1") < 0.05) { hide(); return; }
      if (last.hidden) { last.hidden = false; bar.hidden = false; }
      setIf(bar, "left", "left", Math.round(r.right + 6) + "px");
      setIf(bar, "top", "top", Math.round(r.top) + "px");
      setIf(bar, "height", "height", Math.round(r.height) + "px");
      var th = track.clientHeight;
      var h = Math.max(28, Math.round(th * dc.clientHeight / dc.scrollHeight));
      setIf(thumb, "th", "height", h + "px");
      setIf(thumb, "tt", "transform", "translate(-50%," + Math.round((th - h) * dc.scrollTop / m) + "px)");
    }
    // Solo se mide mientras la ficha está abierta (≈30 veces por segundo, como el fondo).
    var running = false, prevT = 0;
    function loop(t) {
      if (!stage || stage.dataset.mode !== "detail") { running = false; hide(); return; }
      if (t - prevT >= 32) { prevT = t; place(); }
      requestAnimationFrame(loop);
    }
    function wake() { if (!running && stage && stage.dataset.mode === "detail") { running = true; requestAnimationFrame(loop); } }
    if (stage) new MutationObserver(wake).observe(stage, { attributes: true, attributeFilter: ["data-mode"] });
    dc.addEventListener("scroll", place, { passive: true });
    wake();
    function step(dir) { dc.scrollTop = Math.max(0, Math.min(max(), dc.scrollTop + dir * 140)); }
    var drag = null, suppress = false;
    function move(e) {
      if (!drag) return;
      var dy = e.clientY - drag.y;
      if (drag.kind === "thumb") {
        var room = track.clientHeight - thumb.offsetHeight;
        dc.scrollTop = drag.top + (room > 0 ? dy * max() / room : 0);
        e.preventDefault();
      } else {
        if (!drag.moved && Math.abs(dy) > 6) drag.moved = true;
        if (drag.moved) { dc.scrollTop = drag.top - dy; e.preventDefault(); }
      }
    }
    function up() {
      if (drag && drag.kind === "content" && drag.moved) { suppress = true; setTimeout(function () { suppress = false; }, 0); }
      drag = null;
      bar.classList.remove("is-dragging");
      window.removeEventListener("pointermove", move);
      window.removeEventListener("pointerup", up);
      window.removeEventListener("pointercancel", up);
    }
    function begin(kind, e) {
      drag = { kind: kind, y: e.clientY, top: dc.scrollTop, moved: false };
      window.addEventListener("pointermove", move);
      window.addEventListener("pointerup", up);
      window.addEventListener("pointercancel", up);
    }
    thumb.addEventListener("pointerdown", function (e) {
      if (e.button !== 0) return;
      e.preventDefault(); e.stopPropagation();
      bar.classList.add("is-dragging");
      begin("thumb", e);
    });
    track.addEventListener("pointerdown", function (e) {
      if (e.button !== 0 || e.target === thumb) return;
      e.preventDefault(); e.stopPropagation();
      step(e.clientY < thumb.getBoundingClientRect().top ? -2 : 2);
    });
    bar.addEventListener("click", function (e) {
      var b = e.target.closest("[data-yan-step]");
      e.preventDefault(); e.stopPropagation();
      if (b) step(Number(b.getAttribute("data-yan-step")));
    });
    dc.addEventListener("pointerdown", function (e) {
      if (e.button !== 0 || max() <= 1) return;
      begin("content", e);
    });
    dc.addEventListener("click", function (e) {
      if (!suppress) return;
      suppress = false; e.preventDefault(); e.stopPropagation();
    }, true);
    return true;
  }

  function refresh() {
    activeFlag();
    if (typeof window.rhineArchiveRefresh === "function") window.rhineArchiveRefresh();
  }

  // ---- Carga de datos ------------------------------------------------------
  function load() {
    if (!cfg()) return;
    api("/api/ping").then(function (ping) {
      if (!ping || !ping.ok || !ping.roots) throw new Error("ping");
      var roots = ping.roots.slice(0, 5);
      return Promise.all(roots.map(function (r) {
        return api("/api/list", { root: r.id, path: "" }).then(function (res) {
          return { id: r.id, label: r.label, launch: r.launch, items: res && res.ok ? res.items : [] };
        });
      }));
    }).then(function (cols) {
      var next = JSON.stringify(cols);
      if (next === raw) return;
      raw = next;
      columns = cols;
      refresh();
    }).catch(function () {
      if (columns) { columns = null; raw = ""; refresh(); }   // sin puente: volver a los archivos originales
    });
  }

  function start() {
    var tries = 0, stageOk = false, detailOk = false;
    (function wait() {
      if (!stageOk) stageOk = watchStage();
      if (!detailOk) detailOk = watchDetail() && detailScroller();
      if (!(stageOk && detailOk) && tries++ < 100) { setTimeout(wait, 200); return; }
      load();
      setInterval(function () { if (!document.hidden) load(); }, REFRESH_MS);
    })();
  }
  if (document.readyState === "loading") document.addEventListener("DOMContentLoaded", start);
  else start();
})();
