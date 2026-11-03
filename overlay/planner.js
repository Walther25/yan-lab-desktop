/*
 * Yan Lab · Planner
 * Today's tasks y Upcoming events leen sus datos de Yan Bridge (planner.json) y
 * ofrecen botones "+ ADD" que abren la ventana editora (Wallpaper Engine no
 * entrega el teclado al fondo, así que la escritura ocurre en esa ventana).
 * Se engancha al código original mediante window.rhinePlanner (ver patch_planner.py).
 */
(function () {
  "use strict";

  var POLL_MS = 4000;
  var state = { loaded: false, tasks: [], events: [], raw: "" };

  function cfg() {
    var c = window.rhineBridgeConfig;
    return c && c.token && c.port ? c : null;
  }
  function api(path, params, init) {
    var c = cfg();
    var q = new URLSearchParams(params || {});
    q.set("token", c.token);
    return fetch("http://127.0.0.1:" + c.port + path + "?" + q.toString(), Object.assign({ cache: "no-store" }, init || {}))
      .then(function (r) { return r.json(); });
  }
  function esc(s) {
    return String(s == null ? "" : s).replace(/[&<>"']/g, function (ch) {
      return { "&": "&amp;", "<": "&lt;", ">": "&gt;", '"': "&quot;", "'": "&#39;" }[ch];
    });
  }
  function pad(n) { return String(n).padStart(2, "0"); }
  function eventTime(ev) {
    var d = new Date(ev.date + "T" + (ev.time || "00:00") + ":00");
    return isNaN(d) ? null : d.getTime();
  }
  function isToday(ev) {
    var d = new Date();
    return ev.date === d.getFullYear() + "-" + pad(d.getMonth() + 1) + "-" + pad(d.getDate());
  }
  // Próximos eventos: los que aún no pasaron (un evento sin hora cuenta todo su día).
  function upcoming() {
    var now = Date.now();
    return state.events.filter(function (ev) {
      var t = eventTime(ev);
      return t !== null && (t >= now || (!ev.time && isToday(ev)));
    }).sort(function (a, b) { return eventTime(a) - eventTime(b); });
  }
  function fmtDate(ev) { return ev.date.replace(/-/g, ".") + (ev.time ? " " + ev.time : ""); }

  window.rhinePlanner = {
    // Índices de tareas para la lista de la izquierda (undefined = usar las de WE).
    slots: function () {
      return state.loaded ? state.tasks.map(function (_, i) { return i; }) : undefined;
    },
    // Reemplaza las propiedades task1…task6 / eventname / eventdate.
    text: function (key) {
      if (!state.loaded) return undefined;
      var m = /^task(\d+)$/.exec(key);
      if (m) { var t = state.tasks[Number(m[1]) - 1]; return t ? String(t.text).trim().slice(0, 240) : ""; }
      if (key === "eventname" || key === "eventdate") {
        var next = upcoming()[0];
        if (!next) return "";
        return key === "eventname" ? next.name : next.date + (next.time ? " " + next.time : "");
      }
      return undefined;
    },
    tasksHTML: function () {
      if (!cfg()) return undefined;
      var n = state.tasks.length;
      return '<div class="wb-large">' + pad(n) + "<small>" + (n === 1 ? "TASK" : "TASKS") + "</small></div>" +
        '<p class="wb-muted">' + (n ? "Click a task on the left to mark it done; click again to undo. Completion resets daily."
          : "No tasks for today yet.") + "</p>" +
        '<div class="wb-timer-buttons"><button data-planner-open="tasks">' + (n ? "+ Add / edit tasks" : "+ Add tasks") + " ↗</button></div>";
    },
    eventHTML: function () {
      if (!cfg()) return undefined;
      var list = upcoming();
      var btn = '<div class="wb-timer-buttons"><button data-planner-open="events">' + (state.events.length ? "+ Add / edit events" : "+ Add event") + " ↗</button></div>";
      if (!list.length) {
        return '<p class="wb-empty">Keep a date to look forward to.</p><p class="wb-muted">' +
          (state.events.length ? "All your events have passed." : "No upcoming events yet.") + "</p>" + btn;
      }
      var ev = list[0], diff = eventTime(ev) - Date.now();
      var big, unit, line;
      if (diff <= 0) {
        big = "00"; unit = "TODAY"; line = "Happening today · " + esc(fmtDate(ev));
      } else {
        var days = Math.ceil(diff / 864e5);
        big = days; unit = days === 1 ? "DAY TO GO" : "DAYS TO GO";
        var h = Math.floor(diff / 36e5), mi = Math.floor(diff / 6e4) % 60;
        line = "Until target · " + esc(fmtDate(ev)) + "<br>" + h + (h === 1 ? " hour " : " hours ") + mi + (mi === 1 ? " minute" : " minutes") + " to go";
      }
      var more = list.slice(1, 4).map(function (e) {
        return "<li><span>" + esc(fmtDate(e)) + "</span>" + esc(e.name || "Untitled event") + "</li>";
      }).join("");
      return '<p class="wb-event">' + esc(ev.name || "Upcoming event") + "</p>" +
        '<div class="wb-large">' + big + "<small>" + unit + "</small></div>" +
        '<p class="wb-muted">' + line + "</p>" +
        (more ? '<ol class="wb-event-list">' + more + "</ol>" : "") + btn;
    }
  };

  // ---- Redibujar el espacio de trabajo -------------------------------------
  function repaint() {
    var wb = window.rhineWorkbench;
    if (!wb) return;
    try { wb.renderTasks(); wb.renderPanel(); } catch (e) { /* aún iniciando */ }
  }

  // ---- Botón "+ ADD" junto a "Today's tasks" (columna izquierda) -----------
  function injectHeadingButton() {
    var head = document.querySelector(".workbench .wb-heading");
    if (!head || head.querySelector("[data-planner-open]")) return !!head;
    var b = document.createElement("button");
    b.type = "button";
    b.className = "wb-planner-add";
    b.setAttribute("data-planner-open", "tasks");
    b.textContent = "+ ADD";
    var count = head.querySelector(".wb-task-count");
    head.insertBefore(b, count || null);
    return true;
  }

  // ---- Abrir la ventana editora -----------------------------------------------
  document.addEventListener("click", function (e) {
    var b = e.target.closest && e.target.closest("[data-planner-open]");
    if (!b) return;
    e.preventDefault();
    e.stopPropagation();
    if (!cfg()) return;
    var label = b.textContent;
    b.textContent = "OPENING…";
    api("/api/editor", { view: b.getAttribute("data-planner-open") }, { method: "POST" })
      .catch(function () { /* sin puente */ })
      .finally(function () { setTimeout(function () { if (b.isConnected) b.textContent = label; }, 1200); });
  }, true);

  // ---- Datos ------------------------------------------------------------------
  function seedFromWallpaperEngine() {
    // Primera vez: pasar al planner lo que ya estaba en las propiedades de WE.
    var p = (window.rhineWallpaperHost && window.rhineWallpaperHost.properties) || {};
    var val = function (k) { var v = p[k] && p[k].value; return typeof v === "string" ? v.trim() : ""; };
    var tasks = ["task1", "task2", "task3"].map(val).filter(Boolean).map(function (t) { return { text: t }; });
    var events = [];
    var d = val("eventdate"), m = /^(\d{4})-(\d{2})-(\d{2})(?:\s+(\d{2}:\d{2}))?$/.exec(d) || null;
    var m2 = /^(\d{2})-(\d{2})-(\d{4})$/.exec(d);
    if (m) events.push({ name: val("eventname"), date: m[1] + "-" + m[2] + "-" + m[3], time: m[4] || "" });
    else if (m2) events.push({ name: val("eventname"), date: m2[3] + "-" + m2[2] + "-" + m2[1], time: "" });
    return api("/api/planner", {}, { method: "POST", headers: { "Content-Type": "text/plain" }, body: JSON.stringify({ tasks: tasks, events: events }) });
  }
  function apply(res) {
    var raw = JSON.stringify([res.tasks, res.events]);
    var first = !state.loaded;
    state.loaded = true;
    if (raw === state.raw && !first) return;
    state.raw = raw;
    state.tasks = (res.tasks || []).filter(function (t) { return t && t.text; });
    state.events = (res.events || []).filter(function (e) { return e && e.date; });
    repaint();
  }
  function load() {
    if (!cfg()) return;
    api("/api/planner").then(function (res) {
      if (!res || !res.ok) return;
      if (!res.initialized) return seedFromWallpaperEngine().then(function (r) { if (r && r.ok) apply(r); });
      apply(res);
    }).catch(function () {
      if (state.loaded) { state.loaded = false; state.raw = ""; repaint(); }   // sin puente: volver a las propiedades de WE
    });
  }

  function start() {
    var tries = 0;
    (function wait() {
      if (!injectHeadingButton() && tries++ < 150) { setTimeout(wait, 200); return; }
      load();
      setInterval(function () { if (!document.hidden) load(); }, POLL_MS);
      // La lista de la izquierda se vuelve a crear al cambiar de idioma: mantener el botón.
      var today = document.querySelector(".workbench .wb-today");
      if (today) new MutationObserver(function () { injectHeadingButton(); }).observe(today, { childList: true, subtree: true });
    })();
  }
  if (document.readyState === "loading") document.addEventListener("DOMContentLoaded", start);
  else start();
})();
