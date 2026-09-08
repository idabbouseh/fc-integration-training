/* FC Pre-Training Questionnaire — form behavior
 * No dependencies. Progressive enhancement over a native Formspree POST:
 * every question is static HTML, so the form works (with native validation)
 * even if this script never runs.
 *
 * FROZEN BATTERY: C1–C5, C7 and D1 in index.html are re-asked verbatim in
 * the +60-day survey — do not change their wording there. See docs/.
 */
(function () {
  'use strict';

  var DRAFT_KEY = 'fcq-draft-v1';
  var ABE_EMAIL = 'idabbouseh@gmail.com';
  var MAILTO_BODY_LIMIT = 1600;

  var form = null;
  var saveTimer = null;
  var submitted = false;

  /* ------------------------------------------------------------------ *
   * Draft autosave (localStorage, best-effort — every access wrapped)
   * ------------------------------------------------------------------ */

  function collectValues() {
    var data = {};
    var els = form.querySelectorAll('input[name], select[name], textarea[name]');
    els.forEach(function (el) {
      if (el.name === '_gotcha' || el.name === '_subject') return;
      if (el.type === 'radio' || el.type === 'checkbox') {
        if (el.checked) {
          (data[el.name] = data[el.name] || []).push(el.value);
        }
      } else if (el.value !== '') {
        data[el.name] = el.value;
      }
    });
    return data;
  }

  function saveDraft() {
    if (submitted) return;
    try {
      localStorage.setItem(DRAFT_KEY, JSON.stringify(collectValues()));
    } catch (e) { /* storage unavailable — silently skip */ }
  }

  function scheduleSave() {
    if (submitted) return;
    clearTimeout(saveTimer);
    saveTimer = setTimeout(saveDraft, 400);
  }

  function clearDraft() {
    clearTimeout(saveTimer);
    try { localStorage.removeItem(DRAFT_KEY); } catch (e) { /* ignore */ }
  }

  function restoreDraft() {
    var raw = null;
    try { raw = localStorage.getItem(DRAFT_KEY); } catch (e) { return false; }
    if (!raw) return false;
    var data;
    try { data = JSON.parse(raw); } catch (e) { return false; }
    if (!data || typeof data !== 'object') return false;

    var restored = false;
    Object.keys(data).forEach(function (name) {
      var value = data[name];
      var els = form.querySelectorAll('[name="' + CSS.escape(name) + '"]');
      els.forEach(function (el) {
        if (el.type === 'radio' || el.type === 'checkbox') {
          if (Array.isArray(value) && value.indexOf(el.value) !== -1) {
            el.checked = true;
            restored = true;
          }
        } else if (typeof value === 'string') {
          el.value = value;
          restored = true;
        }
      });
    });
    return restored;
  }

  /* ------------------------------------------------------------------ *
   * Interaction rules
   * ------------------------------------------------------------------ */

  // B4: "None of these" is mutually exclusive with the substantive options.
  function wireNoneOfThese() {
    var group = document.getElementById('b4-group');
    if (!group) return;
    group.addEventListener('change', function (e) {
      var boxes = group.querySelectorAll('input[type="checkbox"]');
      var noneBox = group.querySelector('input[data-none]');
      if (!noneBox) return;
      if (e.target === noneBox && noneBox.checked) {
        boxes.forEach(function (b) { if (b !== noneBox) b.checked = false; });
      } else if (e.target !== noneBox && e.target.checked) {
        noneBox.checked = false;
      }
    });
  }

  // B5: "No prior work" checkbox clears and disables the free-text.
  function wireClears() {
    form.querySelectorAll('input[data-clears]').forEach(function (box) {
      var target = document.getElementById(box.getAttribute('data-clears'));
      if (!target) return;
      var apply = function () {
        target.disabled = box.checked;
        if (box.checked) target.value = '';
      };
      box.addEventListener('change', apply);
      apply();
    });
  }

  // D3: at most 3 goals — disable the unchecked once 3 are picked, and say
  // so through a polite live region so the state change isn't silent.
  function wireMaxThree() {
    var group = document.getElementById('d3-group');
    if (!group) return;
    var live = document.getElementById('d3-live');
    var max = parseInt(group.getAttribute('data-max'), 10) || 3;
    var apply = function () {
      var boxes = group.querySelectorAll('input[type="checkbox"]');
      var checked = group.querySelectorAll('input[type="checkbox"]:checked').length;
      boxes.forEach(function (b) { if (!b.checked) b.disabled = checked >= max; });
      if (live) {
        live.textContent = checked >= max
          ? max + ' of ' + max + ' selected — uncheck one to change your picks.'
          : '';
      }
    };
    group.addEventListener('change', apply);
    apply();
  }

  /* ------------------------------------------------------------------ *
   * Validation — inline, DOM order, never clears anything typed
   * ------------------------------------------------------------------ */

  var errorSeq = 0;

  function questionOf(el) {
    while (el && el !== form) {
      if (el.hasAttribute && el.hasAttribute('data-q')) return el;
      el = el.parentNode;
    }
    return null;
  }

  function clearError(question) {
    var msg = question.querySelector('.error-msg');
    if (msg) { msg.hidden = true; msg.textContent = ''; }
    question.classList.remove('has-error');
    question.querySelectorAll('[aria-invalid]').forEach(function (el) {
      el.removeAttribute('aria-invalid');
      el.removeAttribute('aria-describedby');
    });
  }

  function showError(question, message, invalidEls) {
    var msg = question.querySelector('.error-msg');
    if (!msg) return;
    msg.textContent = message;
    msg.hidden = false;
    if (!msg.id) msg.id = 'err-' + (++errorSeq);
    question.classList.add('has-error');
    invalidEls.forEach(function (el) {
      el.setAttribute('aria-invalid', 'true');
      el.setAttribute('aria-describedby', msg.id);
    });
  }

  // Walks questions in document order so the first highlighted problem is
  // also the first one on the page.
  function validate() {
    var firstBad = null;

    form.querySelectorAll('[data-q]').forEach(clearError);

    form.querySelectorAll('[data-q]').forEach(function (q) {
      var kinds = [];
      var invalidEls = [];
      var focusTarget = null;

      q.querySelectorAll('[data-req]').forEach(function (el) {
        if (el.disabled) return;
        if (el.value.trim() === '') {
          kinds.push('field');
          invalidEls.push(el);
          focusTarget = focusTarget || el;
        }
      });

      q.querySelectorAll('[data-req-group]').forEach(function (group) {
        if (!group.querySelector('input:checked')) {
          kinds.push(group.querySelector('input[type="checkbox"]') ? 'checks' : 'radio');
          group.querySelectorAll('input').forEach(function (el) { invalidEls.push(el); });
          focusTarget = focusTarget || group.querySelector('input');
        }
      });

      if (kinds.length) {
        var message =
          kinds.length > 1 ? 'Please complete the highlighted parts of this question.' :
          kinds[0] === 'field' ? 'Please fill this in.' :
          kinds[0] === 'checks' ? 'Please select at least one.' :
          'Please pick an option.';
        showError(q, message, invalidEls);
        firstBad = firstBad || focusTarget;
      }
    });

    // E4: latest start must not be before earliest start
    var earliest = document.getElementById('e4-earliest');
    var latest = document.getElementById('e4-latest');
    if (earliest && latest && earliest.value && latest.value && latest.value < earliest.value) {
      var q = questionOf(latest);
      if (q && !q.classList.contains('has-error')) {
        showError(q, 'Latest start should be the same as or after earliest start.', [latest]);
        firstBad = firstBad || latest;
      }
    }

    return firstBad;
  }

  /* ------------------------------------------------------------------ *
   * Submission
   * ------------------------------------------------------------------ */

  function buildMailtoFallback() {
    var lines = ['FC Pre-Training Questionnaire — submitted via email fallback', ''];
    var data = collectValues();
    Object.keys(data).forEach(function (name) {
      var v = data[name];
      lines.push(name.replace(/_/g, ' ') + ': ' + (Array.isArray(v) ? v.join('; ') : v));
    });
    var body = lines.join('\n');
    if (body.length > MAILTO_BODY_LIMIT) {
      body = body.slice(0, MAILTO_BODY_LIMIT) +
        '\n\n[Long answers were shortened by the email fallback — please paste the rest in before sending.]';
    }
    var subject = 'FC Pre-Training Questionnaire — ' + (data.A1_Name || 'response');
    return 'mailto:' + ABE_EMAIL +
      '?subject=' + encodeURIComponent(subject) +
      '&body=' + encodeURIComponent(body);
  }

  function showConfirmation() {
    submitted = true;
    var name = (document.getElementById('a1-name').value || '').trim().split(/\s+/)[0];
    var confirmName = document.getElementById('confirm-name');
    if (name && confirmName) confirmName.textContent = ', ' + name;
    form.hidden = true;
    var banner = document.getElementById('restore-banner');
    if (banner) banner.hidden = true;
    var conf = document.getElementById('confirmation');
    conf.hidden = false;
    conf.focus();
    clearDraft();
  }

  function wireSubmit() {
    var btn = document.getElementById('submit-btn');
    var status = document.getElementById('form-status');
    var fallback = document.getElementById('fallback-area');
    var mailtoLink = document.getElementById('mailto-fallback');

    // Rebuild at click time so the email always carries the current answers.
    if (mailtoLink) {
      mailtoLink.addEventListener('click', function () {
        mailtoLink.href = buildMailtoFallback();
      });
    }

    form.addEventListener('submit', function (e) {
      e.preventDefault();

      var firstBad = validate();
      if (firstBad) {
        status.textContent = 'A few required answers are missing — they are highlighted above.';
        status.classList.add('is-error');
        var q = questionOf(firstBad);
        (q || firstBad).scrollIntoView({ block: 'center' });
        firstBad.focus({ preventScroll: true });
        return;
      }

      var subjectField = document.getElementById('subject-field');
      var name = (document.getElementById('a1-name').value || '').trim();
      if (subjectField && name) {
        subjectField.value = 'FC Pre-Training Questionnaire — ' + name;
      }

      btn.disabled = true;
      status.classList.remove('is-error');
      status.textContent = 'Sending…';

      fetch(form.action, {
        method: 'POST',
        body: new FormData(form),
        headers: { Accept: 'application/json' }
      }).then(function (res) {
        if (res.ok) {
          showConfirmation();
        } else {
          throw new Error('Relay responded with status ' + res.status);
        }
      }).catch(function () {
        btn.disabled = false;
        btn.textContent = 'Retry sending';
        status.textContent = "That didn't go through — your answers are still here and saved in this browser. Please retry, or use the email option below.";
        status.classList.add('is-error');
        if (mailtoLink) mailtoLink.href = buildMailtoFallback();
        fallback.hidden = false;
      });
    });
  }

  /* ------------------------------------------------------------------ *
   * Boot
   * ------------------------------------------------------------------ */

  document.addEventListener('DOMContentLoaded', function () {
    form = document.getElementById('qform');
    if (!form) return;

    // Native validation stays on for the no-JS path; once JS runs, the
    // richer inline validation takes over.
    form.setAttribute('novalidate', '');

    if (restoreDraft()) {
      var banner = document.getElementById('restore-banner');
      if (banner) banner.hidden = false;
      var fresh = document.getElementById('start-fresh');
      if (fresh) {
        fresh.addEventListener('click', function () {
          clearDraft();
          location.reload();
        });
      }
    }

    wireNoneOfThese();
    wireClears();
    wireMaxThree();
    wireSubmit();

    var onEdit = function (e) {
      scheduleSave();
      var q = questionOf(e.target);
      if (q && q.classList.contains('has-error')) clearError(q);
    };
    form.addEventListener('input', onEdit);
    form.addEventListener('change', onEdit);
  });
})();
