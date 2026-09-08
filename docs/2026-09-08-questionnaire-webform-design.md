# Design spec — Pre-Training Questionnaire web form

Date: 2026-09-08 · Owner: Abe · Status: approved by Abe (enhancement list approved in chat)

## Decisions

| Decision | Choice |
|---|---|
| Hosting | GitHub Pages, public repo `idabbouseh/fc-integration-training` |
| Response relay | Formspree form `mdeoplby` (project *Integration Cross Training*) → email to Abe + dashboard CSV export |
| Content visibility | Published as-is (Abe accepts "SAP Internal"-marked content on an unlisted public URL) |
| Cadence wording | Schedule-neutral ("final program length is being confirmed") — sponsor email says 4 wks Mon–Thu, program doc says ~8 wks weekly; unresolved |
| SSO | One exposure question added (B6); kept out of the frozen battery |
| Deadline | Removed from the page — Abe communicates it by email |
| Verification gate | Nothing publishes until Abe reviews the rendered form |

## Approved changes vs. the Word original (18 items, curated from a 4-lens review)

1. **Q3 hours bands** fixed (overlap at 4) → Under 2 / 2–3 / 4–5 / 6+; per-week, schedule-neutral stem; "practice exercises" not "homework". → A3
2. **Q16 confidence** reworded to today-only capability (was double-barreled with training efficacy). → D1
3. **Section C scales** get behavioral anchors (1 = never seen … 5 = independent + can explain), repeated per row, one-tap chips. → C1–C7
4. **Frozen battery** declared: C1–C5, C7, D1 re-asked verbatim at +60 days, paired by name.
5. **Q14 XML/cXML removed** (nothing in curriculum uses it); signal folded into B5 free-text prompt.
6. **New transforms comfort item** (session 5 + certification requirement had no signal). → C6
7. **New SSO exposure item** (sponsor email lists SSO; curriculum doesn't). → B6
8. **Q18 ranking** → "select up to 3" checkboxes + "which ONE matters most" select; sixth option "Apply standard transforms during load"; fifth option shortened. → D3
9. **Q19 unbundled**: accessibility needs standalone + private email channel; scheduling constraints moved to Section E; learning-style separate. → D4, D5, E5
10. **Q20 structured**: session-length radio, region-grouped time-zone dropdown, Mon–Thu day checkboxes, earliest/latest session START in local 24-h time; "honest windows" line. → E1–E4
11. **Q1 split**: name / role / years-bands (<2, 2–5, 5–10, 10+). Name stays free-text until cohort names are final. → A1
12. **Q7**: added outbound-file/download exposure option; "None of these" mutually exclusive; idioms replaced ("been involved with", "Attended"). → B4
13. **Q5**: added "Several times" middle option. → B2
14. **Tone/ESL pass**: "picking up" → "learning"; "what worries you most" → "which parts look most challenging" + no-commitment line; footer "counts as engagement, not weakness" → "early questions are exactly what shapes the sessions".
15. **Word-to-web hygiene**: instruction block and underscore blanks removed; native radios/checkboxes; optional items tagged; deadline line removed (was TBD).
16. **Privacy architecture**: promise moved to intro and strengthened ("only to Abe — not your manager, not IS; upward reporting is cohort-level only"); reminders atop Sections C and D; POST to private relay (no data in URLs, none in the repo).
17. **Submission reliability**: localStorage autosave (debounced, try/catch, restore banner, cleared on submit); confirmation panel; retry + pre-filled mailto fallback on relay failure; `_gotcha` honeypot.
18. **Accessibility/mobile baseline**: fieldset+legend per question, keyboard-completable, visible focus, AA contrast, errors as text via aria-describedby, 44px+ targets, 16px+ inputs, single column, stacked options on mobile.

Deliberately rejected (YAGNI at n=5): per-task confidence battery, progress indicators, drag-to-rank widgets, timezone auto-detect, conditional show/hide, timing-based bot checks, tenant-provisioning questions (collected by email instead).

## Architecture

Static page: `index.html` (structure + wording) / `styles.css` (design) /
`app.js` (scale rendering from config, autosave, validation, submit).
Native form POST to Formspree works with JS disabled; JS layers on top.
No build step, no dependencies, no data stored server-side by the page.

## Field name → question map

`A1_Name`, `A1_Role`, `A1_YearsFieldglass`, `A2_Modules(+_Other)`, `A3_HoursPerWeek`,
`B1_ConfigManagerIntegrationArea`, `B2_RunResults`, `B3_ManualUpload(+FileKind)`,
`B4_Involvement`, `B5_OutsideExperience(+None)`, `B6_SSOExposure`,
`C1_CSVFiles` … `C7_NewTools`, `D1_ConfidenceToday`, `D2_MostChallenging`,
`D3_Goals`, `D3_TopGoal`, `D4_AccessibilityNeeds`, `D5_AnythingElse`,
`E1_SessionLength`, `E2_TimeZone(+_Other)`, `E3_Days`, `E4_EarliestStart`,
`E4_LatestStart`, `E5_Constraints`.
