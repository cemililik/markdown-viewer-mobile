/**
 * Site interactions: mobile nav toggle, contact form submission.
 */
(function () {
  'use strict';

  document.addEventListener('DOMContentLoaded', function () {
    // ── Mobile hamburger ─────────────────────────────
    var hamburger = document.querySelector('.nav-hamburger');
    var menu = document.querySelector('.nav-menu');
    if (hamburger && menu) {
      hamburger.addEventListener('click', function () {
        var open = menu.classList.toggle('open');
        hamburger.setAttribute('aria-expanded', String(open));
      });

      // Close menu when a nav link is tapped.
      menu.querySelectorAll('a').forEach(function (link) {
        link.addEventListener('click', function () {
          menu.classList.remove('open');
          hamburger.setAttribute('aria-expanded', 'false');
        });
      });
    }

    // ── Contact form (Formspree) ─────────────────────
    var form = document.getElementById('contact-form');
    if (form) {
      form.addEventListener('submit', function (e) {
        e.preventDefault();

        var status = document.getElementById('form-status');
        var btn = form.querySelector('button[type="submit"]');
        var subject = form.querySelector('[name="subject"]');
        var subjectField = form.querySelector('[name="_subject"]');

        // Build subject line.
        if (subject && subjectField) {
          subjectField.value =
            'MarkdownViewer contact request - ' + subject.value;
        }

        btn.disabled = true;

        var data = new FormData(form);

        fetch(form.action, {
          method: 'POST',
          body: data,
          headers: { Accept: 'application/json' },
        })
          .then(function (res) {
            if (res.ok) {
              status.className = 'form-status success';
              var lang = document.documentElement.lang || 'en';
              status.textContent =
                lang === 'tr'
                  ? 'Mesajiniz gonderildi. Tesekkurler!'
                  : 'Message sent successfully. Thank you!';
              form.reset();
            } else {
              throw new Error('Form submission failed');
            }
          })
          .catch(function () {
            status.className = 'form-status error';
            var lang = document.documentElement.lang || 'en';
            status.textContent =
              lang === 'tr'
                ? 'Gonderilemedi. Lutfen daha sonra tekrar deneyin.'
                : 'Could not send. Please try again later.';
          })
          .finally(function () {
            btn.disabled = false;
          });
      });
    }
  });
})();
