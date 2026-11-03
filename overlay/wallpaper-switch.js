/*
 * Yan Lab · Change to Background
 * Botón junto a "Ripple relay" que despliega una mini lista de fondos alternativos
 * (proyectos de myprojects con el botón de regreso "↗ Yan Lab"). Al elegir uno,
 * Yan Bridge cambia SOLO esta pantalla con el control oficial de Wallpaper Engine.
 */
(function () {
  "use strict";

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

  function create() {
    var stage = document.getElementById("stage");
    var relay = stage && stage.querySelector(".relay-entry:not(.yan-switch)");
    var wb = stage && stage.querySelector(".workbench");
    if (!stage || !relay || !wb) return false;
    if (stage.querySelector(".yan-switch")) return true;

    var b = document.createElement("button");
    b.type = "button";
    b.className = "relay-entry yan-switch";
    b.setAttribute("aria-haspopup", "menu");
    b.setAttribute("aria-expanded", "false");
    b.innerHTML = "<span>↗</span> Change to Background";
    b.hidden = true;
    stage.appendChild(b);

    var menu = document.createElement("div");
    menu.className = "yan-bg-menu";
    menu.setAttribute("role", "menu");
    menu.hidden = true;
    stage.appendChild(menu);

    var hud = stage.querySelector(".relay-hud");
    function sync() {
      var gameOn = hud && !hud.hidden;
      b.hidden = !cfg() || wb.hidden || stage.dataset.mode === "boot" || gameOn;
      b.classList.toggle("solo", relay.hidden);   // sin Ripple relay, ocupa su lugar
      menu.classList.toggle("solo", relay.hidden);
      if (b.hidden) close();
    }
    [[stage, "data-mode"], [wb, "hidden"], [relay, "hidden"], [hud, "hidden"]].forEach(function (p) {
      if (p[0]) new MutationObserver(sync).observe(p[0], { attributes: true, attributeFilter: [p[1]] });
    });

    function close() {
      menu.hidden = true;
      b.setAttribute("aria-expanded", "false");
    }
    function render(items, note) {
      menu.innerHTML = '<div class="yan-bg-head">BACKGROUNDS</div>' +
        (items.length ? items.map(function (it) {
          return '<button type="button" role="menuitem" data-bg="' + esc(it.id) + '"><span>↗</span>' + esc(it.name) + "</button>";
        }).join("") : '<p class="yan-bg-note">' + esc(note || "No backgrounds found.") + "</p>");
    }
    function open() {
      render([], "Loading…");
      menu.hidden = false;
      b.setAttribute("aria-expanded", "true");
      api("/api/backgrounds").then(function (res) {
        render(res && res.ok ? res.items : [], res && res.ok ? "" : "Yan Bridge needs an update: run install-bridge.bat.");
      }).catch(function () { render([], "Yan Bridge is offline."); });
    }

    b.addEventListener("click", function (e) {
      e.preventDefault();
      e.stopPropagation();
      if (!cfg()) return;
      if (menu.hidden) open(); else close();
    });
    menu.addEventListener("click", function (e) {
      var item = e.target.closest("[data-bg]");
      e.stopPropagation();
      if (!item) return;
      var id = item.getAttribute("data-bg");
      item.disabled = true;
      item.lastChild.textContent = "Switching…";
      api("/api/wallpaper", { target: id }, { method: "POST", headers: { "Content-Type": "text/plain" }, body: "" })
        .then(function (res) { if (!res || !res.ok) item.lastChild.textContent = "Not available"; })
        .catch(function () { item.lastChild.textContent = "Yan Bridge is offline"; })
        .finally(function () { setTimeout(close, 1500); });
    });
    document.addEventListener("click", function (e) {
      if (!menu.hidden && !menu.contains(e.target) && e.target !== b) close();
    });
    document.addEventListener("keydown", function (e) { if (e.key === "Escape") close(); });

    sync();
    return true;
  }

  function start() {
    var tries = 0;
    (function wait() { if (!create() && tries++ < 150) setTimeout(wait, 200); })();
  }
  if (document.readyState === "loading") document.addEventListener("DOMContentLoaded", start);
  else start();
})();
