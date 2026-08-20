param(
  [string]$Path,
  [int]$Top = 30,
  [switch]$Files
)

# Recursively measure size of immediate children of $Path.
# Outputs a table: Name, GB. Run via:
#   powershell -NoProfile -ExecutionPolicy Bypass -File "<skill>/scripts/measure.ps1" -Path "C:\Users\racfo" -Top 25
# Use -Files to list the largest files directly under $Path instead of subfolders.

if (-not (Test-Path $Path)) { Write-Error "Path not found: $Path"; exit 1 }

if ($Files) {
  Get-ChildItem $Path -File -Force -ErrorAction SilentlyContinue |
    Sort-Object Length -Descending |
    Select-Object -First $Top |
    ForEach-Object { [PSCustomObject]@{Name=$_.Name; GB=[math]::Round($_.Length/1GB,3)} } |
    Format-Table -AutoSize
} else {
  Get-ChildItem $Path -Directory -Force -ErrorAction SilentlyContinue |
    ForEach-Object {
      $s = (Get-ChildItem $_.FullName -Recurse -File -Force -ErrorAction SilentlyContinue |
            Measure-Object Length -Sum).Sum
      [PSCustomObject]@{Name=$_.Name; GB=[math]::Round($s/1GB,2)}
    } |
    Sort-Object GB -Descending |
    Select-Object -First $Top |
    Format-Table -AutoSize
}
