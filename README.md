# FC Integration Cross-Training — Pre-Training Questionnaire

A single-page web form for the SAP Fieldglass FC integration cross-training cohort
(5 functional consultants across US / EMEA / LAC). Converted and enhanced from
`FC_Integration_Pre-Training_Questionnaire.docx`.

**Live form:** https://idabbouseh.github.io/fc-integration-training/

## How responses reach Abe

The form POSTs to Formspree (form `mdeoplby`, project *Integration Cross Training*):

- Each submission arrives by **email** at idabbouseh@gmail.com
  (subject: `FC Pre-Training Questionnaire — <name>`).
- All submissions are listed, with **CSV export**, at
  https://formspree.io/forms/mdeoplby/submissions
- Free tier allows 50 submissions/month — far more than the cohort needs.

No response data ever touches this repository; the page is static.

## Files

| File | Purpose |
|---|---|
| `index.html` | Form structure and all question wording |
| `styles.css` | Visual design (committed light look, mobile-first, WCAG AA) |
| `app.js` | Draft autosave, inline validation, submit/retry/email-fallback, choice rules |
| `docs/2026-09-08-questionnaire-webform-design.md` | Approved design spec and change log vs. the Word original |

## ⚠️ The frozen +60-day battery

Items **C1–C5, C7, and D1** are re-asked verbatim about 60 days after training to
measure the program (pre/post per person, paired by name). **Do not change their
wording, anchors, order, or format** — with only 5 respondents there is no
statistical slack for instrument drift. Each is flagged with a
`FROZEN +60-day battery item` comment in `index.html`.

To run the +60-day re-survey: copy those items into a new page (or duplicate this
form), keep them identical, and drop everything else except the name field.

## Maintenance notes

- **Deadline:** intentionally not on the page — Abe communicates it by email.
- **Cohort names:** `A1_Name` is a free-text input because cohort names weren't
  final at build time. Once they are, consider swapping it for a `<select>` of
  the five names (faster, less typed PII).
- **Endpoint:** defined twice — the `action` attribute on `<form>` in
  `index.html` (no-JS fallback) and nowhere else; `app.js` reads `form.action`.
- **Local preview:** just open `index.html` in a browser. Everything except the
  actual submission works from `file://`.

## Publishing

Served by GitHub Pages from the `main` branch root of
`idabbouseh/fc-integration-training`. Push to `main` to deploy.

## Also in this repo

`fg-mail/` holds a separate tool: a read-only Fieldglass mail triage skill for Joule Work
Desktop and Claude Code, with a one-paste Windows setup. It is not part of the questionnaire
form. See [`fg-mail/README.md`](fg-mail/README.md).
