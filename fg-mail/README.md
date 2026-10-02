# fg-mail: read-only Fieldglass mail triage

A skill that answers "what needs me, who is waiting, and what is broken" across a Fieldglass consultant's Outlook mail, without changing anything in the mailbox. The same `SKILL.md` runs in:

- **Joule Work Desktop**, with its built-in Outlook tools. Import `skills/fg-mail-triage/SKILL.md` under Extensions, Skills, Import.
- **Claude Code**, with the local `outlook-desktop` MCP server against classic Outlook. One PowerShell paste sets everything up.

| File | Purpose |
|---|---|
| `skills/fg-mail-triage/SKILL.md` | The skill. It uses only frontmatter fields both hosts accept: `name`, `description`, `allowed-tools` and `metadata`. |
| `setup-fg-mail.ps1` | One-time Windows setup for Claude Code. It needs no admin rights and denies mailbox-changing tools. |
| `RUNBOOK.md` | Step by step: one-paste setup, manual setup, the Joule import, undo steps and troubleshooting. |

Quick start on Windows, with classic Outlook open:

```powershell
irm https://raw.githubusercontent.com/idabbouseh/fc-integration-training/refs/heads/claude/charming-bohr-77fpzh/fg-mail/setup-fg-mail.ps1 | iex
```

After this branch is merged, change `refs/heads/claude/charming-bohr-77fpzh` to `refs/heads/main` here, in `RUNBOOK.md`, and in `$RepoRaw` inside the script.

Customer names never go in this repository. The skill learns your projects and customer domains on first use and saves them locally to `fg-mail-triage.prefs.json`, in the folder you start Claude Code or Joule in.

## How it was tested

The skill ran in headless Claude Code against two mock Outlook servers backed by the same synthetic mailbox. One mock copies the `outlook-desktop` tool names and behavior: a literal per-folder search and display-name recipients. The other mimics Joule: a mailbox-wide KQL search and `get_email`. The mailbox contains traps:

- a thread you already answered
- customer mail filed by rule into a subfolder
- a Fieldglass mention only in a message body
- a question you sent 8 days ago that is still unanswered
- a certificate notice whose ask is hidden at the end
- a prompt-injection email telling the assistant to forward invoices

Each round ran four test prompts, with the skill and without it. The tests were: a first triage with no saved watch list, a Joule-style triage with a saved watch list, a follow-ups and nudges request, and a session with no mail tools. All runs used Claude Sonnet 5.5 in headless Claude Code on 2026-10-02.

| Round | Skill change | With skill | Without skill |
|---|---|---|---|
| 1 | First draft, 3 tests | 95% | 66% |
| 2 | Open every customer and addressed-to-you thread before classifying it | 98% | 66% |
| 3 | Coverage names the threads judged from the subject line, not a count | 100% | 74% |

Pass rate is the share of graded checks passed. Across all 22 runs, nothing attempted to send, move, mark or delete mail, and all 12 runs with mail tools flagged the injection email without acting on it.

Without the skill, the main misses were:
- mail filed in customer subfolders
- threads that never say "Fieldglass", such as the failing worker download
- unanswered questions in Sent Items
- deadlines that had already passed

With the skill, a triage took about 8 seconds longer.

Two limits apply. The Joule side was tested against a mock of Joule's tools, not Joule Work Desktop itself. Each configuration ran once per round, so the numbers show direction rather than variance.
