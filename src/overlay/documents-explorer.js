/*
 * Yan Lab · Desktop explorer
 * Convierte la ventana ARCHIVE INDEX en un explorador con pestañas
 * (PC settings · Clients · Apps · Games · Documents) usando el marcado y los
 * estilos originales (result-row, category-filters…). Los datos y la acción de
 * abrir vienen de Rhine Bridge (servidor local en 127.0.0.1).
 * No modifica el código original del fondo: solo observa y extiende el DOM.
 */
(function () {
  "use strict";

  var POLL_MS = 4000;
  var MODE_KEY = "rhine-docs-mode";
  var ROOT_KEY = "rhine-docs-root";
  var CODES = { "pc-settings": "SYS", clients: "CLNT", apps: "APP", games: "GAME", documents: "DOC" };

  function cfg() {
    var c = window.rhineBridgeConfig;
    return c && c.token && c.port ? c : null;
  }
  function api(path, params, init) {
    var c = cfg();
    var q = new URLSearchParams(params || {});
    q.set("token", c.token);
    var ctrl = typeof AbortController === "function" ? new AbortController() : null;
    var timer = ctrl ? setTimeout(function () { ctrl.abort(); }, 4000) : 0;
    var opts = Object.assign({ cache: "no-store" }, init || {});
    if (ctrl) opts.signal = ctrl.signal;
    return fetch("http://127.0.0.1:" + c.port + path + "?" + q.toString(), opts)
      .then(function (r) {
        return r.json().catch(function () { return { ok: false, error: "http-" + r.status }; });
      })
      .finally(function () { clearTimeout(timer); });
  }
  function esc(s) {
    return String(s == null ? "" : s).replace(/[&<>"']/g, function (ch) {
      return { "&": "&amp;", "<": "&lt;", ">": "&gt;", '"': "&quot;", "'": "&#39;" }[ch];
    });
  }
  function fold(s) {
    return String(s).normalize("NFD").replace(/[̀-ͯ]/g, "").toLowerCase();
  }
  function pad2(n) { return String(n).padStart(2, "0"); }
  function fmtDate(iso) {
    var d = new Date(iso);
    if (isNaN(d)) return "";
    return d.getFullYear() + "." + pad2(d.getMonth() + 1) + "." + pad2(d.getDate()) +
      " " + pad2(d.getHours()) + ":" + pad2(d.getMinutes());
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
  function typeLabel(it) {
    if (it.dir) return "FOLDER";
    var e = it.ext, t = (it.target || "").toLowerCase();
    if (e === ".url") {
      if (t === "steam") return "STEAM SHORTCUT";
      if (t.indexOf("epicgames") >= 0) return "EPIC GAMES SHORTCUT";
      if (t === "http" || t === "https") return "WEB LINK";
      return "URL SHORTCUT";
    }
    if (e === ".lnk") return it.target ? "SHORTCUT · " + it.target.toUpperCase() : "SHORTCUT";
    if (it.launch && e === ".exe") return "PROGRAM";
    if (it.launch && e === ".jar") return "JAVA PROGRAM";
    if (it.blocked) return (e ? e.slice(1).toUpperCase() + " · " : "") + "SHOWN IN EXPLORER";
    if (it.kind === "pdf") return "PDF DOCUMENT";
    if (/^\.(docx?|docm|dotx?|odt|rtf)$/.test(e)) return "WORD DOCUMENT";
    if (/^\.(xlsx?|xlsm|xlsb|xltx?|csv|ods)$/.test(e)) return "SPREADSHEET";
    if (/^\.(pptx?|pptm|potx|odp)$/.test(e)) return "PRESENTATION";
    if (it.kind === "office") return "OFFICE FILE";
    if (it.kind === "image") return "IMAGE";
    return e ? e.slice(1).toUpperCase() + " FILE" : "FILE";
  }
  function store(key, val) {
    try { if (val === undefined) return localStorage.getItem(key); localStorage.setItem(key, val); } catch (e) { /* sin almacenamiento */ }
    return null;
  }

  // Estado que sobrevive a cerrar y abrir la ventana (durante esta ejecución).
  var memory = { root: store(ROOT_KEY) || "", paths: {}, roots: null };

  function enhance(modal) {
    var input = modal.querySelector("#archive-search");
    var filters = modal.querySelector(".category-filters");
    var header = modal.querySelector(".result-header");
    var results = modal.querySelector("#search-results");
    var count = modal.querySelector("#result-count");
    var bottomRight = modal.querySelector(".modal-bottom > span:last-child");
    if (!input || !filters || !header || !results || !count) return;
    modal.dataset.docsEnhanced = "1";

    var original = {
      header: header.innerHTML,
      placeholder: input.getAttribute("placeholder") || "",
      bottom: bottomRight ? bottomRight.innerHTML : "",
      query: ""
    };
    var st = {
      on: false, roots: memory.roots, root: memory.root, path: "", query: "",
      data: null, raw: "", status: "idle", busy: false, flash: ""
    };

    // ---- Controles añadidos ------------------------------------------------
    var origButtons = Array.prototype.slice.call(filters.querySelectorAll("[data-filter]"));
    var enterBtn = button("data-docs-enter", "Desktop ↗", "");
    filters.insertBefore(enterBtn, filters.firstChild);
    var tabBox = document.createElement("span");
    tabBox.className = "docs-tabs docs-hide";
    tabBox.style.display = "contents";
    filters.appendChild(tabBox);
    var exitBtn = button("data-docs-exit", "← Yan Lab archives", "docs-hide");
    filters.appendChild(exitBtn);

    // ---- Desplazamiento compatible con Wallpaper Engine ---------------------
    // En el escritorio, WE no siempre entrega a la página el arrastre de la barra
    // nativa ni la rueda; esta barra propia y el arrastre de la lista usan solo
    // eventos de puntero, que sí llegan (los mismos que mueven el arreglo 3D).
    var wrap = document.createElement("div");
    wrap.className = "docs-scroll-wrap";
    results.parentNode.insertBefore(wrap, results);
    wrap.appendChild(results);
    var bar = document.createElement("div");
    bar.className = "docs-scrollbar";
    bar.hidden = true;
    bar.innerHTML = '<button type="button" data-docs-scroll="-1" aria-label="Scroll up">▲</button>' +
      '<div class="docs-track"><i class="docs-thumb"></i></div>' +
      '<button type="button" data-docs-scroll="1" aria-label="Scroll down">▼</button>';
    wrap.appendChild(bar);
    var track = bar.querySelector(".docs-track");
    var thumb = bar.querySelector(".docs-thumb");

    function maxScroll() { return Math.max(0, results.scrollHeight - results.clientHeight); }
    function updateBar() {
      var max = maxScroll();
      var show = max > 1 && getComputedStyle(results).overflowY !== "visible";
      bar.hidden = !show;
      wrap.classList.toggle("has-bar", show);
      if (!show) return;
      var th = track.clientHeight;
      var h = Math.max(28, Math.round(th * results.clientHeight / results.scrollHeight));
      thumb.style.height = h + "px";
      thumb.style.transform = "translate(-50%," + Math.round((th - h) * results.scrollTop / max) + "px)";
    }
    function scrollByStep(dir) {
      results.scrollTop = Math.max(0, Math.min(maxScroll(), results.scrollTop + dir * 152));
    }
    results.addEventListener("scroll", updateBar, { passive: true });
    window.addEventListener("resize", updateBar);
    new MutationObserver(function () { requestAnimationFrame(updateBar); }).observe(results, { childList: true });

    var drag = null;          // arrastre del pulgar o de la lista
    var suppressClick = false;
    function onMove(e) {
      if (!drag) return;
      var dy = e.clientY - drag.y;
      if (drag.kind === "thumb") {
        var room = track.clientHeight - thumb.offsetHeight;
        results.scrollTop = drag.top + (room > 0 ? dy * maxScroll() / room : 0);
        e.preventDefault();
      } else {
        if (!drag.moved && Math.abs(dy) > 6) { drag.moved = true; wrap.classList.add("is-dragging"); }
        if (drag.moved) { results.scrollTop = drag.top - dy; e.preventDefault(); }
      }
    }
    function onUp() {
      if (!drag) return;
      if (drag.kind === "list" && drag.moved) {
        suppressClick = true;
        setTimeout(function () { suppressClick = false; }, 0);
      }
      drag = null;
      wrap.classList.remove("is-dragging");
      bar.classList.remove("is-dragging");
      window.removeEventListener("pointermove", onMove);
      window.removeEventListener("pointerup", onUp);
      window.removeEventListener("pointercancel", onUp);
    }
    function startDrag(kind, e) {
      drag = { kind: kind, y: e.clientY, top: results.scrollTop, moved: false };
      window.addEventListener("pointermove", onMove);
      window.addEventListener("pointerup", onUp);
      window.addEventListener("pointercancel", onUp);
    }
    thumb.addEventListener("pointerdown", function (e) {
      if (e.button !== 0) return;
      e.preventDefault(); e.stopPropagation();
      bar.classList.add("is-dragging");
      startDrag("thumb", e);
    });
    track.addEventListener("pointerdown", function (e) {
      if (e.button !== 0 || e.target === thumb) return;
      e.preventDefault(); e.stopPropagation();
      var r = thumb.getBoundingClientRect();
      scrollByStep(e.clientY < r.top ? -2.5 : 2.5);
    });
    bar.addEventListener("click", function (e) {
      e.stopPropagation(); e.preventDefault();
      var b = e.target.closest("[data-docs-scroll]");
      if (b) scrollByStep(Number(b.getAttribute("data-docs-scroll")));
    });
    results.addEventListener("pointerdown", function (e) {
      if (e.button !== 0 || maxScroll() <= 1) return;
      startDrag("list", e);
    });
    // Tras arrastrar la lista, el clic que genera el navegador no debe abrir nada.
    results.addEventListener("click", function (e) {
      if (!suppressClick) return;
      suppressClick = false;
      e.stopPropagation(); e.preventDefault();
    }, true);

    function button(attr, text, cls) {
      var b = document.createElement("button");
      b.type = "button";
      b.setAttribute(attr, "");
      b.textContent = text;
      if (cls) b.className = cls;
      return b;
    }
    function rootById(id) {
      return (st.roots || []).filter(function (r) { return r.id === id; })[0] || null;
    }
    function renderTabs() {
      tabBox.innerHTML = (st.roots || []).map(function (r) {
        var on = r.id === st.root;
        return '<button type="button" data-docs-root="' + esc(r.id) + '" class="' + (on ? "active" : "") +
          '" aria-pressed="' + on + '">' + esc(r.label) + "</button>";
      }).join("");
    }

    // ---- Modo --------------------------------------------------------------
    function enter(focusInput) {
      if (st.on) return;
      st.on = true;
      store(MODE_KEY, "docs");
      modal.classList.add("docs-mode");
      original.query = input.value;
      input.value = st.query;
      input.setAttribute("placeholder", "Search by name");
      origButtons.concat(enterBtn).forEach(function (b) { b.classList.add("docs-hide"); });
      [tabBox, exitBtn].forEach(function (b) { b.classList.remove("docs-hide"); });
      if (!cfg()) st.status = "unconfigured";
      render({ resetScroll: true });
      connect();
      if (focusInput) input.focus({ preventScroll: true });
    }
    function exit() {
      if (!st.on) return;
      st.on = false;
      store(MODE_KEY, "archive");
      modal.classList.remove("docs-mode");
      st.query = input.value;
      input.value = original.query;
      input.setAttribute("placeholder", original.placeholder);
      header.innerHTML = original.header;
      if (bottomRight) bottomRight.innerHTML = original.bottom;
      [tabBox, exitBtn].forEach(function (b) { b.classList.add("docs-hide"); });
      origButtons.concat(enterBtn).forEach(function (b) { b.classList.remove("docs-hide"); });
      // El código original vuelve a dibujar su lista.
      var active = origButtons.filter(function (b) { return b.classList.contains("active"); })[0] || origButtons[0];
      if (active) active.click();
      results.scrollTop = 0;
      updateBar();
      enterBtn.focus({ preventScroll: true });
    }

    // ---- Datos -------------------------------------------------------------
    function connect() {
      if (!cfg()) { st.status = "unconfigured"; render(); return; }
      if (st.roots && st.roots.length) { selectRoot(st.root, true); return; }
      st.status = "loading"; render();
      api("/api/ping").then(function (res) {
        if (res && res.ok && res.roots && res.roots.length) {
          st.roots = memory.roots = res.roots;
          selectRoot(st.root, true);
        } else {
          st.status = res && res.error === "token" ? "unconfigured" : "error"; render();
        }
      }).catch(function () { st.status = "offline"; render(); });
    }
    function selectRoot(id, keepPath) {
      var r = rootById(id) || st.roots[0];
      if (st.root && st.root !== r.id) memory.paths[st.root] = st.path;
      st.root = memory.root = r.id;
      store(ROOT_KEY, r.id);
      st.path = keepPath ? (memory.paths[r.id] || "") : (memory.paths[r.id] || "");
      st.data = null; st.raw = "";
      if (!keepPath) { st.query = ""; input.value = ""; }
      renderTabs();
      load(st.path, false);
    }
    function load(path, silent) {
      if (!cfg()) { st.status = "unconfigured"; render(); return; }
      if (!st.roots) { connect(); return; }
      if (st.busy) return;
      st.busy = true;
      var root = st.root;
      if (!silent && !st.data) { st.status = "loading"; render(); }
      api("/api/list", { root: root, path: path })
        .then(function (res) {
          if (root !== st.root) return;              // cambió de pestaña mientras tanto
          if (res && res.ok) {
            var raw = JSON.stringify(res);
            var changedFolder = !st.data || st.data.path !== res.path;
            st.path = memory.paths[root] = res.path;
            st.status = "ok";
            if (raw !== st.raw || changedFolder) {
              st.raw = raw; st.data = res;
              render(changedFolder ? { resetScroll: true } : { keep: true });
            } else {
              renderBottom();
            }
          } else if (res && res.error === "missing" && path) {
            st.busy = false;
            load(parentOf(path), silent);             // la carpeta ya no existe: subir
            return;
          } else if (res && res.error === "token") {
            st.status = "unconfigured"; st.data = null; st.raw = ""; render();
          } else {
            st.status = "error"; render();
          }
        })
        .catch(function () { st.status = "offline"; st.data = null; st.raw = ""; st.roots = memory.roots = null; render(); })
        .finally(function () { st.busy = false; });
    }
    function parentOf(p) {
      var parts = String(p || "").split(/[\\/]/).filter(Boolean);
      parts.pop();
      return parts.join("\\");
    }
    function navigate(path) {
      st.query = ""; input.value = "";
      st.path = path; st.data = null; st.raw = "";
      load(path, false);
    }
    function openItem(it, reveal) {
      if (!cfg() || !it) return;
      flash((it.launch ? "LAUNCHING · " : "OPENING · ") + displayName(it));
      api("/api/open", {}, {
        method: "POST",
        headers: { "Content-Type": "text/plain" },
        body: JSON.stringify({ root: st.root, path: it.path, reveal: !!reveal })
      }).then(function (res) {
        if (!res || !res.ok) flash(res && res.error === "missing" ? "FILE NOT FOUND" : "COULD NOT OPEN");
        else if (res.action === "reveal" && !reveal) flash("SHOWN IN EXPLORER · " + it.name);
        if (res && res.error === "missing") load(st.path, true);
      }).catch(function () { flash("BRIDGE OFFLINE"); st.status = "offline"; render(); });
    }
    var flashTimer = 0;
    function flash(text) {
      st.flash = text;
      renderBottom();
      clearTimeout(flashTimer);
      flashTimer = setTimeout(function () { st.flash = ""; renderBottom(); }, 2200);
    }

    // ---- Dibujo ------------------------------------------------------------
    function visibleItems() {
      if (!st.data) return [];
      var q = fold(st.query.trim());
      return st.data.items.filter(function (it) { return !q || fold(it.name).indexOf(q) >= 0; });
    }
    function renderHeader() {
      var root = rootById(st.root);
      var parts = String(st.path || "").split(/[\\/]/).filter(Boolean);
      var crumbs = ['<button type="button" data-docs-crumb=""' + (parts.length ? "" : ' class="docs-current"') + ">" +
        esc(root ? root.label : "Desktop") + "</button>"];
      var acc = [];
      parts.forEach(function (p, i) {
        acc.push(p);
        crumbs.push('<i aria-hidden="true">/</i><button type="button" data-docs-crumb="' + esc(acc.join("\\")) + '"' +
          (i === parts.length - 1 ? ' class="docs-current" aria-current="location"' : "") + ">" + esc(p) + "</button>");
      });
      if (st.status === "ok") {
        crumbs.push('<button type="button" class="docs-open-current" data-docs-open-current title="Open this folder in File Explorer" aria-label="Open this folder in File Explorer">↗</button>');
      }
      header.innerHTML = '<span class="docs-crumbs">' + crumbs.join("") + "</span><span>TYPE · SIZE · MODIFIED</span><span>ACCESS</span>";
    }
    function renderBottom() {
      if (!st.on) return;
      var text = st.status === "ok" ? pad2(visibleItems().length) + " RECORDS FOUND" : "00 RECORDS FOUND";
      if (st.status === "ok" && st.data && st.data.truncated) text += " · FIRST " + st.data.items.length + " OF " + st.data.total;
      if (st.flash) text = st.flash;
      count.textContent = text;
      if (bottomRight) {
        var label = st.status === "ok" ? "CONNECTED" : st.status === "loading" ? "CONNECTING" :
          st.status === "unconfigured" ? "NOT INSTALLED" : "OFFLINE";
        bottomRight.innerHTML = "YAN BRIDGE <i>●</i> " + label;
      }
    }
    function emptyBlock(title, body, btn) {
      return '<div class="empty-results" data-docs-owned><span>∅</span><strong>' + esc(title) + "</strong><p>" + body + "</p>" +
        (btn ? '<button type="button" data-docs-retry>' + esc(btn) + "</button>" : "") + "</div>";
    }
    function row(it, idx) {
      var code = it.dir ? "DIR" : it.launch ? (CODES[st.root] || "APP") : ((it.ext || "").slice(1, 5).toUpperCase() || "FILE");
      var access = it.dir ? "BROWSE" : it.launch ? "LAUNCH" : it.blocked ? "REVEAL" : "OPEN";
      var meta = it.dir ? "Folder · " + fmtDate(it.mtime)
        : it.launch && /^\.(lnk|url)$/.test(it.ext) ? "Shortcut · " + fmtDate(it.mtime)
        : fmtSize(it.size) + " · " + fmtDate(it.mtime);
      return '<button type="button" class="result-row docs-row" data-docs-owned data-docs-item="' + idx +
        '" data-docs-path="' + esc(it.path) + '" title="' + esc(it.name) + '">' +
        '<span class="result-name"><b>' + esc(code) + "</b><span>" + esc(displayName(it)) +
        "<small>" + esc(typeLabel(it)) + "</small></span></span>" +
        "<span>" + esc(meta) + "</span>" +
        "<span>" + access + ' <i data-docs-open title="' + (it.dir ? "Open in File Explorer" : access === "LAUNCH" ? "Launch" : "Open") + '">↗</i></span></button>';
    }
    function render(opts) {
      if (!st.on) return;
      opts = opts || {};
      var focusedPath = null;
      var ae = document.activeElement;
      if (opts.keep && ae && ae.dataset && ae.dataset.docsPath != null) focusedPath = ae.dataset.docsPath;
      var scroll = results.scrollTop;

      renderTabs();
      renderHeader();
      var html;
      if (st.status === "unconfigured") {
        html = emptyBlock("Yan Bridge is not installed",
          "Run <b>install-bridge.bat</b> in the <b>yan-bridge</b> folder of this wallpaper, then reload it in Wallpaper Engine.", "Retry →");
      } else if (st.status === "offline" || st.status === "error") {
        html = emptyBlock("Yan Bridge is not responding",
          "The local bridge is not running. Run <b>install-bridge.bat</b> again, or sign out and back in.", "Retry →");
      } else if (!st.data) {
        html = '<div class="empty-results" data-docs-owned><span>…</span><strong>Connecting</strong><p></p></div>';
      } else {
        var list = visibleItems();
        if (!list.length) {
          html = st.data.items.length
            ? emptyBlock("No matching items", "Try another name.", "Reset search →")
            : emptyBlock("This folder is empty", "Items you add here will appear automatically.", st.path ? "↑ Parent folder" : "");
        } else {
          html = list.map(function (it) { return row(it, st.data.items.indexOf(it)); }).join("");
        }
      }
      results.innerHTML = html;
      results.scrollTop = opts.resetScroll ? 0 : scroll;
      updateBar();
      if (focusedPath != null) {
        var again = Array.prototype.filter.call(results.querySelectorAll(".docs-row"), function (r) {
          return r.dataset.docsPath === focusedPath;
        })[0];
        if (again) again.focus({ preventScroll: true });
      }
      renderBottom();
    }

    // ---- Eventos -----------------------------------------------------------
    modal.addEventListener("click", function (e) {
      var t = e.target.closest("button");
      if (!t || !modal.contains(t)) return;
      var mine = t.matches("[data-docs-enter],[data-docs-exit],[data-docs-root],[data-docs-crumb],[data-docs-open-current],[data-docs-retry],[data-docs-item]");
      if (!mine) return;
      e.stopPropagation();
      e.preventDefault();
      if (t.hasAttribute("data-docs-enter")) { enter(true); return; }
      if (t.hasAttribute("data-docs-exit")) { exit(); return; }
      if (t.hasAttribute("data-docs-root")) {
        var id = t.getAttribute("data-docs-root");
        if (id !== st.root) selectRoot(id, false);
        return;
      }
      if (t.hasAttribute("data-docs-crumb")) { navigate(t.getAttribute("data-docs-crumb")); return; }
      if (t.hasAttribute("data-docs-open-current")) { openItem({ name: st.path || "folder", path: st.path, launch: false }, false); return; }
      if (t.hasAttribute("data-docs-retry")) {
        if (st.data && st.data.items.length) { st.query = ""; input.value = ""; render(); }
        else if (st.data && st.path) navigate(parentOf(st.path));
        else { st.roots = memory.roots = null; connect(); }
        return;
      }
      var it = st.data && st.data.items[Number(t.getAttribute("data-docs-item"))];
      if (!it) return;
      var onArrow = !!e.target.closest("[data-docs-open]");
      if (it.dir && !onArrow) navigate(it.path);
      else openItem(it, false);
    });

    input.addEventListener("input", function (e) {
      if (!st.on) return;
      e.stopPropagation();            // el buscador original no debe redibujar la lista
      st.query = input.value;
      render({ resetScroll: true });
    });

    modal.addEventListener("keydown", function (e) {
      if (!st.on) return;
      var r = e.target.closest && e.target.closest(".docs-row");
      if ((e.key === "ArrowDown" || e.key === "ArrowUp") && (r || e.target === input)) {
        var rows = Array.prototype.slice.call(results.querySelectorAll(".docs-row"));
        if (!rows.length) return;
        e.preventDefault();
        var i = r ? rows.indexOf(r) : -1;
        var next = e.key === "ArrowDown" ? Math.min(rows.length - 1, i + 1) : i - 1;
        if (next < 0) input.focus({ preventScroll: true });
        else rows[next].focus();
        return;
      }
      if ((e.key === "ArrowLeft" || e.key === "ArrowRight") && r && st.roots) {
        e.preventDefault();
        var ix = st.roots.map(function (x) { return x.id; }).indexOf(st.root);
        var n = st.roots[(ix + (e.key === "ArrowRight" ? 1 : st.roots.length - 1)) % st.roots.length];
        selectRoot(n.id, false);
        return;
      }
      if ((e.key === "Backspace" && e.target !== input) || (e.altKey && e.key === "ArrowUp")) {
        if (st.path) { e.preventDefault(); navigate(parentOf(st.path)); }
      }
    });

    // Si el código original redibuja la lista (p. ej. cambio de idioma), recuperarla.
    new MutationObserver(function () {
      if (st.on && !results.querySelector("[data-docs-owned]")) render({ keep: true });
    }).observe(results, { childList: true });

    // Actualización automática mientras la ventana está abierta.
    var poll = setInterval(function () {
      if (!modal.isConnected) { clearInterval(poll); return; }
      if (!st.on || !cfg() || document.hidden) return;
      if (st.status === "ok") load(st.path, true);
      else if (st.status === "offline" || st.status === "error") connect();
    }, POLL_MS);

    if ((store(MODE_KEY) || "docs") === "docs") enter(false);
  }

  function scan() {
    var modal = document.querySelector(".terminal-modal");
    if (!modal || modal.dataset.docsEnhanced) return;
    var h2 = modal.querySelector("h2");
    if (!h2 || h2.textContent.trim().indexOf("ARCHIVE INDEX") !== 0) return;
    if (!modal.querySelector("#archive-search")) return;
    try { enhance(modal); } catch (err) { console.error("[rhine-docs]", err); }
  }
  function start() {
    // Las ventanas del fondo se crean dentro de #modal-root: basta con vigilar ese contenedor.
    var host = document.getElementById("modal-root");
    if (host) new MutationObserver(scan).observe(host, { childList: true });
    else new MutationObserver(function () {
      var h = document.getElementById("modal-root");
      if (h) { this.disconnect(); new MutationObserver(scan).observe(h, { childList: true }); scan(); }
    }).observe(document.body, { childList: true, subtree: true });
    scan();
  }
  if (document.readyState === "loading") document.addEventListener("DOMContentLoaded", start);
  else start();
})();
