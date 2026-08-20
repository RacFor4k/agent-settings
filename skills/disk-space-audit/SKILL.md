---
name: disk-space-audit
description: Read-only disk-space audit for Windows. Use when the user says the drive is full, wants to know what takes up space, free up disk, find junk/leftovers from uninstalled programs, or clean C:\. Produces a grouped Markdown report (safe to delete / uncertain / movable) without modifying or deleting anything unless explicitly asked.
---

# Disk Space Audit (Windows, read-only)

Analyze what consumes space on a Windows drive and produce a triage report. The
default mode is **investigation only** — never delete, move, or modify files unless
the user explicitly asks. The whole point is to give the user a safe, actionable map.

## When to trigger
- "диск C переполнен / почти полон", "не хватает места", "что занимает место"
- "найди мусор / остатки удалённых программ / временные файлы"
- "почисти диск", "освободи место", "что можно удалить / перенести"
- "составь отчёт по диску"

## Hard rules
- **Read-only by default.** Scan with `Get-ChildItem -Recurse -File` (sizes only). Do not
  run `Remove-Item`, `powercfg`, `Dism`, `cleanmgr`, or any mutating command unless the
  user explicitly requested the cleanup step. Show such commands in the report as
  *recommendations*, not executed.
- **Never delete system files** (`pagefile.sys`, `hiberfil.sys`, `WinSxS`) by hand.
- Treat `AppData\Local\Packages` and Store/MSIX data as **ASK** — deleting breaks apps.
- Always confirm the target drive and the user profile path before scanning.

## Measurement tool
Use the bundled script instead of re-deriving PowerShell inline — it avoids cmd.exe
quoting issues and is deterministic.

```
powershell -NoProfile -ExecutionPolicy Bypass -File "<skill>/scripts/measure.ps1" -Path "<dir>" -Top 25
```

For the largest files in a folder (e.g. `Downloads`):
```
powershell -NoProfile -ExecutionPolicy Bypass -File "<skill>/scripts/measure.ps1" -Path "C:\Users\racfo\Downloads" -Top 40 -Files
```

If the tool returns empty stdout (common when `Format-Table` runs without a TTY), append
`> out.txt 2>&1` and read `out.txt` with `read_file`:
```
powershell -NoProfile -ExecutionPolicy Bypass -File "<skill>/scripts/measure.ps1" -Path "<dir>" -Top 25 > "C:\Users\racfo\scan.txt" 2>&1
```

> `<skill>` = this skill's directory (`C:\Users\racfo\.agents\skills\disk-space-audit`).

If you must inline, use this exact pattern (it is the one proven to survive cmd.exe):
```powershell
Get-ChildItem '<dir>' -Directory -Force -ErrorAction SilentlyContinue |
  ForEach-Object {
    $s=(Get-ChildItem $_.FullName -Recurse -File -Force -ErrorAction SilentlyContinue | Measure-Object Length -Sum).Sum
    [PSCustomObject]@{Name=$_.Name; GB=[math]::Round($s/1GB,2)}
  } | Sort-Object GB -Descending | Select-Object -First 25 | Format-Table -AutoSize
```
**Gotchas learned the hard way:**
- Do NOT use `Select-Object @{N='X';E={...}}` computed properties when the command runs
  through `cmd.exe` — they get silently eaten and you get empty output. Build
  `[PSCustomObject]@{...}` inside a `ForEach-Object` loop instead.
- `Format-Table | Out-File` can produce an empty *stdout* while still writing the file.
  When in doubt, write to a temp `.txt` and read it back with `read_file`.
- `Get-Item` on `hiberfil.sys`/`pagefile.sys` can return NOT FOUND; measure them via
  `Get-ChildItem -Force` at the drive root.
- Large recursions (a 150 GB profile) are slow — run them in the background or with a
  long timeout, and write to a file.

## Workflow
1. **Baseline.** Report total/used/free from `Get-PSDrive C`. Scan top-level folders of
   the drive: `Users`, `Windows`, `Program Files`, `Program Files (x86)`, `ProgramData`,
   `$Recycle.Bin`. Also size the root system files (`pagefile.sys`, `hiberfil.sys`,
   `swapfile.sys`) via `Get-ChildItem C:\ -Force`.
2. **Drill the biggest.** Usually `Users\<profile>` dominates. Scan its children, then
   `AppData\Local`, `AppData\Roaming`, `AppData\LocalLow` separately (each is huge).
3. **Scan Programs.** `Program Files`, `Program Files (x86)`, `ProgramData` top folders.
   `Windows\WinSxS` separately.
4. **Downloads.** List largest files (installers/ISOs) — classic "download and forget".
5. **Junk sweep.** Cross-reference findings against
   `references/junk-patterns.md`. Run the empty-folder finder there to surface leftovers
   from uninstalled programs.
6. **Write the report** (see template) to the user's `Documents` folder
   (`C:\Users\<profile>\Documents\disk_space_report.md`) unless they ask elsewhere.
7. **Summarize in chat**, grouped exactly as the report: delete / uncertain / move.

## Report template (always group like this)
```markdown
# Отчёт по диску C:\ — <date>

## Итог
Всего / Занято / Свободно + таблица топ-уровня (папка, ГБ, доля).

## Детализация
По каждому крупному разделу — таблицы (папка, ГБ, комментарий) на 2-3 уровня вглубь.

## Мелкий мусор / остатки удалённых программ
Список подозрительных мелких/пустых папок + команда поиска пустых папок.

## ГРУППИРОВКА
### ✅ Точно можно удалять
таблица (что, ГБ, почему) — кэши, Temp, Корзина, установщики.
### ⚠️ Не точно — нужно подтверждение
таблица (что, ГБ, риск) — Store-пакеты, встроенный Python, Modrinth-дубликаты,
используемые Adobe/Blackmagic, пользовательские данные.
### 📦 Можно перенести на другой диск
таблица (что, ГБ, как) — игры/моды, Docker, крупные файлы Downloads, профильные папки.
### 🔧 Системные файлы (по желанию)
hiberfil (powercfg -h off), pagefile (уменьшить), WinSxS (Dism) — только как совет.

## Рекомендованные команды очистки (НЕ выполнены)
npm/nuget/uv cache clean, Dism, cleanmgr — как справка.
```
Sizes in ГБ (decimal, 1 ГБ = 10⁹ B), rounded. Note missing ~GB from permission-denied
skips so the user knows the total is an underestimate.

## Triage legend (from references/junk-patterns.md)
Read `references/junk-patterns.md` for the full folder-by-folder cheat-sheet
(caches, installers, games/launchers, per-user apps, leftovers, system files). When a
scanned folder matches a pattern there, label it **DEL / ASK / MOVE / SYS** accordingly.

## Output language
Respond in the user's language (Russian by default here). Keep the chat summary short;
put the detail in the Markdown file.
