/**
 * Lightweight i18n switcher for MarkdownViewer site.
 *
 * Convention:
 *   <span class="i18n-inline" data-lang="en">English</span>
 *   <span class="i18n-inline" data-lang="tr">Turkish</span>
 *
 *   <div class="i18n-block" data-lang="en">...</div>
 *   <div class="i18n-block" data-lang="tr">...</div>
 *
 * The active language gets the .active class; others are hidden via CSS.
 */
(function () {
  'use strict';

  const STORAGE_KEY = 'mdv-lang';
  const SUPPORTED = ['en', 'tr'];
  const DEFAULT = 'en';

  function detectLanguage() {
    const stored = localStorage.getItem(STORAGE_KEY);
    if (stored && SUPPORTED.includes(stored)) return stored;

    const nav = navigator.language || navigator.userLanguage || '';
    const prefix = nav.split('-')[0].toLowerCase();
    return SUPPORTED.includes(prefix) ? prefix : DEFAULT;
  }

  function setLanguage(lang) {
    if (!SUPPORTED.includes(lang)) return;
    localStorage.setItem(STORAGE_KEY, lang);
    document.documentElement.lang = lang;

    document.querySelectorAll('[data-lang]').forEach(function (el) {
      el.classList.toggle('active', el.dataset.lang === lang);
    });

    document.querySelectorAll('.lang-toggle button').forEach(function (btn) {
      btn.classList.toggle('active', btn.dataset.setLang === lang);
    });
  }

  // Initialise on DOM ready.
  document.addEventListener('DOMContentLoaded', function () {
    setLanguage(detectLanguage());

    document.querySelectorAll('.lang-toggle button').forEach(function (btn) {
      btn.addEventListener('click', function () {
        setLanguage(btn.dataset.setLang);
      });
    });
  });

  // Expose for programmatic use.
  window.MDVi18n = { setLanguage: setLanguage };
})();
