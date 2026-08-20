# PIPELINE.INSTRUCTIONS.md

Operating rules and domain-specific tool guidance for autonomous agents.

## 1. Core Operating Constraints
- **Verify primary sources:** Never trust comments or memory. Inspect live code, run tests, or check tool output before claiming success.
- **Precision edits:** Prefer `edit` over `write` for existing files. Read the target section before editing.
- **Code style & formatting:** Match the existing formatting and code style of the file/repo.
- **Process discipline:** State assumptions explicitly when input is ambiguous. Never stop at a partial fix or end tasks with conversational fluff.

---

## 2. Advanced Reasoning & Memory MCPs

- **sequentialthinking**:
  * *Trigger:* Ambiguous problems, complex multi-file refactoring, debugging hard bugs, or when initial approach fails.
  * *Rule:* Deconstruct the problem into step-by-step thoughts. Revise hypotheses dynamically before touching code. Do not skip on complex tasks.

- **Memory Graph (`memory_*`)**:
  * *Trigger:* Long-term facts, architectural decisions, user preferences, or core module relationships worth preserving across sessions.
  * *Rule:* Search/read entities before creating duplicates. Only persist high-signal structural knowledge, not temporary logs or ephemeral code snippets.

---

## 3. Platform-Specific Tools & Gotchas

- **background_process** (instead of `bash &`):
  * *Trigger:* Long-running dev servers, watchers, or background daemons.
  * *Rule:* Never use `&` or `nohup` in `bash`. Use `background_process(action:"start", command:"...", ready:{...})`.

- **Web & Context7 Docs (`context7_*`, `webfetch`, `websearch`)**:
  * *Trigger:* Up-to-date framework/library documentation and external APIs.
  * *Rule:* Always run `context7_resolve-library-id` first, then `context7_query-docs`. If resolution fails or library is not found, immediately fall back to `websearch`.

- **Agent Manager (`agent_manager`, `agent_manager_models`)**:
  * *Trigger:* Managing VS Code extension sessions and worktrees.
  * *Rule:* Always `list` first to get real IDs. Do not confuse with one-shot `task` subagents.

- **Browser Automation (`kilo-playwright_browser_*`)**:
  * *Trigger:* UI testing, scraping, end-to-end web workflows.
  * *Rule:* Prefer `snapshot` (accessibility tree) over screenshots to locate elements; use `wait_for` before interacting.

- **Local Recall (`kilo_local_recall`)**:
  * *Trigger:* Retrieving context, past refactoring decisions, or user preferences in this repository.
  * *Rule:* Query before starting large architectural changes to preserve past repo conventions.

- **Visualizations (`chart` vs Mermaid)**:
  * *Data charts (bar, line, pie):* Use `chart` with Chart.js v4 JSON specs.
  * *Flowcharts / Sequence / Architecture:* Write Mermaid blocks (````mermaid ... ````) directly in markdown.

---

## 4. Skills Index
Activate via `skill({name: "..."})` before planning/executing matching workflows:
- **plan** / **research**:
  * *Trigger:* Complex/unfamiliar codebases or multi-step architecture design prior to modifying code.
- **frontend-design**:
  * *Trigger:* Creating or overhauling production-grade UI mockups, pages, and components.
- **cross-review** / **zen-review**:
  * *Trigger:* Multi-model or targeted code review after completing non-trivial code modifications.
- **cavecrew**:
  * *Trigger:* Parallelizable tasks that can be delegated to isolated, compressed subagents.
- **grill-me**:
  * *Trigger:* Ambiguous or incomplete task specifications — run an interactive interview to disambiguate before implementation.
- **agent-browser**:
  * *Trigger:* Advanced, multi-step browser QA and scripted interactions.

---

## 5. Self-Review Loop (run before declaring done)
1. **Verified:** Did I run tests/checks and inspect output, rather than assuming it works?
2. **Formatted:** Does the code match project conventions?
3. **Clean & Complete:** No orphan debug logs, no broken edge cases, no trailing fluff questions.