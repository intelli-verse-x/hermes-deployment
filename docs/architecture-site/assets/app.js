// Theme, mobile nav, copy buttons, code tabs. No dependencies.
(function () {
  // Theme: dark default, persisted.
  var saved = null;
  try { saved = localStorage.getItem("llmdocs-theme"); } catch (e) {}
  if (saved === "light") document.documentElement.setAttribute("data-theme", "light");

  document.addEventListener("DOMContentLoaded", function () {
    var toggle = document.querySelector(".theme-toggle");
    if (toggle) {
      var setLabel = function () {
        var light = document.documentElement.getAttribute("data-theme") === "light";
        toggle.textContent = light ? "\u{1F319} Dark mode" : "\u2600\uFE0F Light mode";
      };
      setLabel();
      toggle.addEventListener("click", function () {
        var light = document.documentElement.getAttribute("data-theme") === "light";
        if (light) {
          document.documentElement.removeAttribute("data-theme");
        } else {
          document.documentElement.setAttribute("data-theme", "light");
        }
        try { localStorage.setItem("llmdocs-theme", light ? "dark" : "light"); } catch (e) {}
        setLabel();
      });
    }

    // Mobile menu
    var menuBtn = document.querySelector(".menu-btn");
    if (menuBtn) {
      menuBtn.addEventListener("click", function () {
        document.querySelector(".sidebar").classList.toggle("open");
      });
    }

    // Copy buttons on every <pre>
    document.querySelectorAll("pre").forEach(function (pre) {
      var btn = document.createElement("button");
      btn.className = "copy-btn";
      btn.textContent = "Copy";
      btn.addEventListener("click", function () {
        var code = pre.querySelector("code");
        var text = code ? code.innerText : pre.innerText;
        navigator.clipboard.writeText(text).then(function () {
          btn.textContent = "Copied!";
          setTimeout(function () { btn.textContent = "Copy"; }, 1600);
        });
      });
      pre.appendChild(btn);
    });

    // Tabs: .tabs > .tab-bar > button[data-tab] + .tab-panel[data-tab]
    document.querySelectorAll(".tabs").forEach(function (tabs) {
      var buttons = tabs.querySelectorAll(".tab-bar button");
      buttons.forEach(function (btn) {
        btn.addEventListener("click", function () {
          buttons.forEach(function (b) { b.classList.remove("active"); });
          btn.classList.add("active");
          tabs.querySelectorAll(".tab-panel").forEach(function (p) {
            p.classList.toggle("active", p.dataset.tab === btn.dataset.tab);
          });
        });
      });
    });
  });
})();
