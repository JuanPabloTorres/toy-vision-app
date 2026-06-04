<#
.SYNOPSIS
  Find exact-bit duplicate images across the ToyVision raw dataset.

.DESCRIPTION
  Phase 3.10 helper. Reads every .jpg under raw/*/*.jpg, hashes each
  with SHA-1, and reports any hash that appears in more than one file.
  Read-only — never deletes or modifies files; the cleanup decision is
  yours.

  Why this script exists:
    inspect_raw.ps1 enforces the filename convention, but two files with
    different (class, scene-tag) names can still hold the same bytes if
    you accidentally re-imported the same camera-roll frame. Bit-identical
    duplicates inflate the training count without adding any new
    information.

  Near-duplicates (perceptually similar but not bit-identical) are NOT
  detected here. Those need a perceptual-hash tool and are out of scope
  for a defensive Phase 3.10 helper.

.PARAMETER Root
  Path to the dataset root. Defaults to $HOME\toyvision-dataset-v0_1.

.EXAMPLE
  pwsh tools/training/dataset/detect_duplicates.ps1
  pwsh tools/training/dataset/detect_duplicates.ps1 -Root D:\datasets\toyvision
#>

[CmdletBinding()]
param(
  [string]$Root = (Join-Path $HOME 'toyvision-dataset-v0_1')
)

$ErrorActionPreference = 'Stop'

$RawRoot = Join-Path $Root 'raw'
if (-not (Test-Path -LiteralPath $RawRoot)) {
  Write-Error "raw/ not found at $RawRoot."
  exit 1
}

$images = Get-ChildItem -LiteralPath $RawRoot -Recurse -File -Filter '*.jpg' -ErrorAction SilentlyContinue
if (-not $images -or $images.Count -eq 0) {
  Write-Output ""
  Write-Output "No .jpg files found under $RawRoot. Nothing to deduplicate."
  Write-Output ""
  exit 0
}

Write-Output ""
Write-Output "Hashing $($images.Count) image(s) under $RawRoot..."

$byHash = @{}
$processed = 0
$total = $images.Count
foreach ($img in $images) {
  $processed++
  if ($processed % 50 -eq 0 -or $processed -eq $total) {
    Write-Progress -Activity 'Hashing dataset' -Status "$processed / $total" -PercentComplete ([int](100.0 * $processed / $total))
  }

  $hash = (Get-FileHash -LiteralPath $img.FullName -Algorithm SHA1).Hash
  if (-not $byHash.ContainsKey($hash)) {
    $byHash[$hash] = New-Object System.Collections.Generic.List[System.IO.FileInfo]
  }
  $byHash[$hash].Add($img)
}
Write-Progress -Activity 'Hashing dataset' -Completed

$dupGroups = $byHash.GetEnumerator() | Where-Object { $_.Value.Count -gt 1 }

Write-Output ""
if (-not $dupGroups -or @($dupGroups).Count -eq 0) {
  Write-Output "No exact-bit duplicates found across $($images.Count) image(s)."
  Write-Output ""
  exit 0
}

$dupGroupCount = @($dupGroups).Count
$dupFileCount = 0
foreach ($g in $dupGroups) { $dupFileCount += $g.Value.Count }

Write-Output "DUPLICATES FOUND"
Write-Output "================"
Write-Output "$dupGroupCount group(s) of bit-identical files, covering $dupFileCount file(s) total."
Write-Output ""

$groupIdx = 0
foreach ($g in $dupGroups) {
  $groupIdx++
  Write-Output "Group ${groupIdx} (sha1 $($g.Key.Substring(0, 16))...):"
  $sortedFiles = $g.Value | Sort-Object FullName
  for ($i = 0; $i -lt $sortedFiles.Count; $i++) {
    $f = $sortedFiles[$i]
    $rel = $f.FullName.Substring($RawRoot.Length + 1)
    $marker = if ($i -eq 0) { 'keep?' } else { 'dup ?' }
    Write-Output "  [$marker] $rel"
  }
  Write-Output ""
}

Write-Output "These files share identical bytes. You almost certainly want to keep"
Write-Output "one and delete the others. The script does NOT delete anything — you"
Write-Output "decide which copy stays and remove the rest manually."
Write-Output ""

# Exit code 1 if any duplicates were found, so this can gate a training run.
exit 1
