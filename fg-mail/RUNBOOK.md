# Runbook: Fieldglass mail triage in Claude Code and Joule

Last checked: 2026-10-02 · Laptop: Windows, classic Outlook

At the end, a Claude Code session runs on your laptop and reads your Outlook mailbox through a local MCP server. It needs no Entra app and no admin consent. You drive it from claude.ai/code or the Claude mobile app, and the `fg-mail-triage` skill turns "triage my Fieldglass mail" into a prioritized, read-only report.

In Joule Work Desktop you only need the skill file. See [Joule Work Desktop](#joule-work-desktop).

## Before you start

- **Data handling.** In Claude Code, mail content goes to Anthropic under your Claude plan's terms. A personal Pro or Max plan uses consumer terms with no DPA. Joule Work Desktop keeps the same triage inside SAP-governed tooling. Decide which fits the mail you'll triage.
- **Read-only by design.** The skill never sends, moves or deletes. The setup script also denies every mailbox-changing tool in Claude Code's own permission rules, so a write is blocked even if something asks for one.
- **This cloud session can't reach your laptop.** The Remote Control session you start in step 3 is a separate session in your claude.ai/code list.

## Option A: one paste (recommended)

1. **Switch to classic Outlook.** In the new Outlook, turn off the **New Outlook** toggle at the top right. Leave classic Outlook open. If the toggle is missing, IT has hidden it, and Option A won't work. Use Joule instead.
2. **Open PowerShell as yourself, not as admin,** and paste:

   ```powershell
   irm https://raw.githubusercontent.com/idabbouseh/fc-integration-training/refs/heads/claude/charming-bohr-77fpzh/fg-mail/setup-fg-mail.ps1 | iex
   ```

   The script prints a status line for each of its 8 steps and a summary at the end. It keeps going past any step it can't finish, so one failure doesn't waste the rest.
3. **Sign in once, then start Remote Control:**

   ```powershell
   cd $env:USERPROFILE\fg-mail
   claude
   ```

   Type `/login`, finish in the browser with the Claude account that has your plan, then type `/exit`. Then:

   ```powershell
   claude remote-control --name "FG mail"
   ```

   Answer `y` to "Enable Remote Control?" and to "Trust this folder?".
4. **Open claude.ai/code** or the Claude app, pick **FG mail**, and ask:

   ```text
   triage my Fieldglass mail from the last week
   ```

   On the first run the skill infers your projects and customer domains from the mail and asks whether to save them. They are saved to `fg-mail-triage.prefs.json` in your work folder, on your laptop only.

If the paste fails because GitHub is blocked or scripts are restricted, download the setup ZIP from the chat, extract it, and run this from the extracted folder:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\setup-fg-mail.ps1
```

If the script reports "Constrained Language Mode", your laptop doesn't allow PowerShell scripts. Use Option B.

## What the script changes, and how to undo it

| What | Where | Undo |
|---|---|---|
| Claude Code, only if missing | `%USERPROFILE%\.local\bin` | `claude` uninstall steps at code.claude.com/docs/en/setup |
| Python 3.12, only if no 3.12+ exists | Per-user install | Settings > Apps |
| `outlook-desktop-mcp` 0.3.0 | Your user's Python packages | `python -m pip uninstall outlook-desktop-mcp` |
| Server registration | `%USERPROFILE%\.claude.json` | `claude mcp remove outlook-desktop --scope user` |
| Permission rules | `%USERPROFILE%\.claude\settings.json` | Restore `settings.json.bak-fg-mail` |
| The skill | `%USERPROFILE%\.claude\skills\fg-mail-triage` | Delete the folder |
| Work folder and log | `%USERPROFILE%\fg-mail` | Delete the folder |

The permission rules allow the five mail-reading tools without a prompt and deny all 16 tools that change the mailbox, calendar, tasks or rules. To be asked before every read instead, run the script with `-AskBeforeReading`:

```powershell
& ([scriptblock]::Create((irm https://raw.githubusercontent.com/idabbouseh/fc-integration-training/refs/heads/claude/charming-bohr-77fpzh/fg-mail/setup-fg-mail.ps1))) -AskBeforeReading
```

### Why this Outlook package

`outlook-desktop-mcp` 0.3.0 was reviewed from its PyPI source on 2026-10-02:
- It talks to your local classic Outlook over COM and to Claude Code over standard input and output.
- It contains no network code.
- Reading a message does not mark it read.
- Its author lists a Microsoft address.

The script pins this exact version, so an update can't change it without a review. It does not work with the new Outlook, because `olk.exe` has no COM interface.

## Option B: manual steps

1. Switch to classic Outlook, as in Option A.
2. Install Python 3.12 or newer from python.org: per-user, with **Add python.exe to PATH** ticked.
3. Install Claude Code: `irm https://claude.ai/install.ps1 | iex`, then open a new PowerShell window.
4. Install and register the Outlook server:

   ```powershell
   python -m pip install --user outlook-desktop-mcp==0.3.0
   claude mcp add --scope user outlook-desktop '--' (Get-Command python).Source -m outlook_desktop_mcp
   claude mcp list
   ```

5. Add these rules to `%USERPROFILE%\.claude\settings.json`, merging them into any `permissions` block already there:

   ```json
   {
     "permissions": {
       "allow": [
         "Skill(fg-mail-triage)",
         "mcp__outlook-desktop__list_accounts",
         "mcp__outlook-desktop__list_emails",
         "mcp__outlook-desktop__read_email",
         "mcp__outlook-desktop__list_folders",
         "mcp__outlook-desktop__search_emails"
       ],
       "deny": [
         "mcp__outlook-desktop__send_email", "mcp__outlook-desktop__reply_email",
         "mcp__outlook-desktop__move_email", "mcp__outlook-desktop__mark_as_read",
         "mcp__outlook-desktop__mark_as_unread", "mcp__outlook-desktop__set_category",
         "mcp__outlook-desktop__save_attachment", "mcp__outlook-desktop__create_event",
         "mcp__outlook-desktop__create_meeting", "mcp__outlook-desktop__update_event",
         "mcp__outlook-desktop__delete_event", "mcp__outlook-desktop__respond_to_meeting",
         "mcp__outlook-desktop__create_task", "mcp__outlook-desktop__complete_task",
         "mcp__outlook-desktop__delete_task", "mcp__outlook-desktop__toggle_rule"
       ]
     }
   }
   ```

6. Copy `skills\fg-mail-triage\SKILL.md` to `%USERPROFILE%\.claude\skills\fg-mail-triage\SKILL.md`.
7. Continue with Option A, steps 3 and 4.

## Joule Work Desktop

1. In Joule Work Desktop, open **Extensions**, then **Skills**, then **+ New**, then **Import**.
2. Select `SKILL.md`, or the ZIP from the chat.
3. Ask Joule: "triage my Fieldglass mail from the last week".

Joule uses its own built-in Outlook tools, so the setup script and classic Outlook don't apply there. The skill stores its watch list with Joule's file tools, in Joule's working folder.

## What a triage gives you

- **Do first today:** up to five items.
- **One table per project:** each row shows who is waiting on whom, the ask, the due date, the age in business days and the next step.
- **Integration alerts:** failed uploads and downloads, SFTP, connector, SAML and certificate errors.
- **Waiting on others:** follow-ups, with ready-to-copy nudges.
- **Suspicious mail:** for example, a message addressing the AI assistant. It is listed and never acted on.
- **Coverage:** what was scanned, and what was judged from the subject line only.

Other requests that work: "what's waiting on me", "what am I waiting on", "follow-ups for Globex", "triage today", "pre-sales threads this week".

## Troubleshooting

| Symptom | Cause | Fix |
|---|---|---|
| `/mcp` shows outlook-desktop failed | Outlook closed, or still on new Outlook | Open classic Outlook, check Task Manager shows `OUTLOOK.EXE`, restart `claude` |
| COM error or "class not registered" | New Outlook only | Step 1 |
| Outlook asks "A program is trying to access..." | Corporate Outlook security policy | Choose **Allow access for 10 minutes** |
| `claude remote-control` exits with a login error | Not signed in through claude.ai, or an API key is set | Run `claude`, then `/login`; unset `ANTHROPIC_API_KEY` and `ANTHROPIC_BASE_URL` |
| The session never shows up at claude.ai/code | Corporate proxy blocks api.anthropic.com | Try another network to confirm, then ask IT |
| Skill doesn't trigger | Skill not installed | Check `%USERPROFILE%\.claude\skills\fg-mail-triage\SKILL.md` exists, or type `/fg-mail-triage` |
| pip install fails | Proxy blocks pypi.org | Ask IT, or install from a network that allows it |
