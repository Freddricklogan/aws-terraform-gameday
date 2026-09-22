/* Scheme toggle for pages on theme-tokens.css that are not on the Executive Shell.
 * Same contract as exec-shell.js: dark unless localStorage['exec-scheme'] === 'light';
 * a sun/moon button (#exec-scheme-toggle) is appended to the first `[data-scheme-toggle]`
 * host, else to the first <header>. Load it with a plain <script> (no module needed). */
(function () {
  var KEY = 'exec-scheme';
  var root = document.documentElement;
  var SUN = '<svg viewBox="0 0 24 24" width="16" height="16" aria-hidden="true" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round"><circle cx="12" cy="12" r="4"/><path d="M12 2v2M12 20v2M4.9 4.9l1.4 1.4M17.7 17.7l1.4 1.4M2 12h2M20 12h2M4.9 19.1l1.4-1.4M17.7 6.3l1.4-1.4"/></svg>';
  var MOON = '<svg viewBox="0 0 24 24" width="16" height="16" aria-hidden="true" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><path d="M21 12.8A9 9 0 1 1 11.2 3a7 7 0 0 0 9.8 9.8z"/></svg>';

  function current() { return root.getAttribute('data-scheme') === 'light' ? 'light' : 'dark'; }
  function apply(scheme, persist) {
    if (scheme === 'light') root.setAttribute('data-scheme', 'light');
    else root.removeAttribute('data-scheme');
    root.style.colorScheme = scheme;
    if (persist) { try { localStorage.setItem(KEY, scheme); } catch (e) { /* storage unavailable */ } }
    document.dispatchEvent(new CustomEvent('exec-scheme-change', { detail: { scheme: scheme } }));
  }
  var stored = null;
  try { stored = localStorage.getItem(KEY); } catch (e) { /* ignore */ }
  apply(stored === 'light' ? 'light' : 'dark', false);

  var CSS = '.scheme-toggle{display:inline-flex;align-items:center;justify-content:center;padding:8px 9px;line-height:0;'
    + 'border:1px solid var(--border);border-radius:8px;background:var(--panel-2);color:var(--text);cursor:pointer}'
    + '.scheme-toggle:hover{border-color:var(--accent);color:var(--accent)}'
    + '.scheme-toggle:focus-visible{outline:2px solid var(--accent);outline-offset:2px}';

  function mount() {
    if (document.getElementById('exec-scheme-toggle')) return;
    var style = document.createElement('style'); style.textContent = CSS; document.head.appendChild(style);
    var host = document.querySelector('[data-scheme-toggle]') || document.querySelector('header');
    if (!host) return;
    var btn = document.createElement('button');
    btn.type = 'button'; btn.id = 'exec-scheme-toggle'; btn.className = 'scheme-toggle';
    var render = function () {
      var light = current() === 'light';
      btn.innerHTML = light ? MOON : SUN;
      btn.setAttribute('aria-label', light ? 'Switch to the dark palette' : 'Switch to the light palette');
      btn.title = btn.getAttribute('aria-label');
    };
    btn.addEventListener('click', function () { apply(current() === 'light' ? 'dark' : 'light', true); render(); });
    render();
    host.appendChild(btn);
  }
  if (document.readyState === 'loading') document.addEventListener('DOMContentLoaded', mount); else mount();
})();
