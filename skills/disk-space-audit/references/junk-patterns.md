# Known space hogs & junk patterns (Windows)

Use this as a triage cheat-sheet when reading `measure.ps1` output. Categories:
**DEL** = safe to delete (re-downloads/regenerates), **ASK** = confirm with user first,
**MOVE** = relocate to another disk via symlink, **SYS** = system file, handle carefully.

## Caches (DEL — regenerate automatically)
- `AppData\Local\Temp` — temp files
- `AppData\Local\SquirrelTemp` — installer leftovers
- `AppData\Local\npm-cache` + `Roaming\npm` (cache part) — `npm cache clean --force`
- `.nuget` (profile) + `AppData\Local\NuGet` — NuGet global cache (`dotnet nuget locals all --clear`)
- `AppData\Local\uv` + `Roaming\uv` — Python `uv` cache
- `AppData\Local\pypoetry` + `Roaming\pypoetry` — Poetry cache
- `AppData\Local\go-build` — Go build cache (`go clean -cache`)
- `AppData\Local\NVIDIA*` + `ProgramData\NVIDIA*` — driver GL/shader cache
- `AppData\Local\Mozilla\...` + `Roaming\Mozilla` — Firefox cache (keep profile if used)
- Browser caches: `Chrome\User Data\...`, `Discord\...`, `Telegram Desktop\...` (mostly DEL, but media in Telegram is ASK)

## Installers / downloads (DEL if program already installed; MOVE if large data)
- `Downloads` — pile of `.exe/.msi/.iso/.zip`. Top offenders are usually ISO images and big archives.
- `RVC*.7z`, `*.iso`, `*.tar.part` — large data, prefer MOVE to D:.

## Games & launchers (MOVE or DEL if unused)
- `AppData\Local\Roblox`, `AppData\Roaming\ModrinthApp` / `ModrinthApp2` (Minecraft mods — **watch for duplicate "2" suffix**), `AppData\Roaming\.tlauncher`, `CurseForge`, `AppData\LocalLow\Ludeon Studios` (RimWorld), `Colossal Order` (Cities Skylines)
- `Program Files (x86)\Steam` — move game library

## Per-user apps (ASK — may be needed)
- `AppData\Local\Programs` — VS Code, Python embed, Notion, CurseForge installed per-user
- `AppData\Local\Packages` — MSIX/Store apps (DEL breaks them)
- `AppData\Roaming\Code` — VS Code settings/extensions
- `AppData\Local\Microsoft`, `Roaming\Microsoft` — Office/OneDrive/Teams caches (partially DEL)

## Leftover / unknown (likely junk — ASK before deleting)
- `AppData\Local\camoufox` — Firefox fork, often unused
- `AppData\Roaming\Urban Cyber Security`, `9router`, `gg.essential.mod` — unknown provenance
- Empty folders from uninstalled programs (see empty-folder finder below)

## System files (SYS — do NOT delete by hand)
- `pagefile.sys`, `hiberfil.sys`, `swapfile.sys` — virtual memory / hibernation. Reclaim via
  `powercfg -h off` (hiberfil) or shrink pagefile in System Properties. Needs admin.
- `Windows\WinSxS` — clean only with `Dism.exe /Online /Cleanup-Image /StartComponentCleanup`
- `Windows\Temp`, `Windows\SoftwareDistribution` — OS self-maintains; usually near-empty

## Empty-folder finder (leftover junk)
```powershell
Get-ChildItem 'C:\Users\<user>' -Recurse -Directory -Force -ErrorAction SilentlyContinue |
Where-Object { (Get-ChildItem $_.FullName -Force -ErrorAction SilentlyContinue).Count -eq 0 } |
Select-Object FullName
```
