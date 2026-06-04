<#
.SYNOPSIS
  Scan the local ToyVision raw dataset, count images per class, lint filenames
  against the canonical naming convention, and report Day-N progress.

.DESCRIPTION
  Phase 3.10 helper. Reads only — never deletes, moves, or modifies files.
  Pure status report; safe to run as often as you like.

  Validates:
    - Folder layout under raw/ matches the canonical 14 + holding classes.
    - Every file in raw/<class>/ is a .jpg.
    - Every filename matches: <class>__<scene-tag>__<NNNN>.jpg
      where:
        <class>      matches the parent folder name (raw/toy_car/ → toy_car).
        <scene-tag>  is one of the allowed scene tags.
        <NNNN>       is a 4-digit zero-padded counter.

  Does NOT validate (these need human review):
    - Whether the image content actually matches the class.
    - Privacy (faces, children, private info).
    - Whether the variation matrix is met.

.PARAMETER Root
  Path to the dataset root. Defaults to $HOME\toyvision-dataset-v0_1.

.PARAMETER Day
  Day number (1, 2, or 3) for target progress reporting. Defaults to 1.

.EXAMPLE
  pwsh tools/training/dataset/inspect_raw.ps1
  pwsh tools/training/dataset/inspect_raw.ps1 -Day 2
  pwsh tools/training/dataset/inspect_raw.ps1 -Root D:\datasets\toyvision -Day 3
#>

[CmdletBinding()]
param(
  [string]$Root = (Join-Path $HOME 'toyvision-dataset-v0_1'),
  [int]$Day = 1
)

$ErrorActionPreference = 'Stop'

$RawRoot = Join-Path $Root 'raw'
if (-not (Test-Path -LiteralPath $RawRoot)) {
  Write-Error "raw/ not found at $RawRoot. Create the dataset structure first (see .toyvision/model-training/dataset-capture-pass.md)."
  exit 1
}

# Canonical 14-label set plus the special folders.
$CanonicalClasses = @(
  'toy_car','toy_truck','doll','stuffed_animal','building_blocks',
  'ball','action_figure','toy_train','puzzle','board_game',
  'not_toy','person_no_face','pet','book'
)
$SpecialFolders = @('negative_only','uncertain_review')

# Day-N raw targets (matches .toyvision/model-training/dataset-capture-pass.md
# §"Daily plan").
$Day1Targets = @{
  'toy_car'         = 25
  'stuffed_animal'  = 25
  'ball'            = 20
  'building_blocks' = 15
  'book'            = 10
  'not_toy'         = 5
}
$Day2Targets = @{
  'toy_car'         = 40
  'toy_truck'       = 20
  'doll'            = 20
  'stuffed_animal'  = 40
  'building_blocks' = 25
  'ball'            = 30
  'action_figure'   = 15
  'toy_train'       = 15
  'not_toy'         = 15
  'book'            = 15
}
$Day3Targets = @{
  'toy_car'         = 50
  'toy_truck'       = 40
  'doll'            = 40
  'stuffed_animal'  = 50
  'building_blocks' = 40
  'ball'            = 40
  'action_figure'   = 30
  'toy_train'       = 30
  'puzzle'          = 25
  'board_game'      = 20
  'not_toy'         = 30
  'book'            = 20
  'pet'             = 10
  'person_no_face'  = 10
}

$Targets = switch ($Day) {
  1 { $Day1Targets }
  2 { $Day2Targets }
  3 { $Day3Targets }
  default { $Day1Targets }
}

# Allowed scene tags (matches dataset-capture-pass.md §"Scene tags").
$AllowedTags = @(
  'floor','bin','shelf','mixed','occluded','lowlight',
  'topdown','closeup','farshot','lookalike','negative'
)

# Filename pattern: <class>__<scene-tag>__<NNNN>.jpg
# We capture class/tag/counter to validate separately.
$NamePattern = '^([a-z_]+)__([a-z]+)__(\d{4})\.jpg$'

$report = [pscustomobject]@{
  Root                = $Root
  Day                 = $Day
  TotalFiles          = 0
  TotalImages         = 0
  ClassFolders        = @()
  UnknownFolders      = @()
  Violations          = New-Object System.Collections.Generic.List[string]
  ClassCounts         = @{}
  Progress            = @()
}

# Discover folders that actually exist
$existing = Get-ChildItem -LiteralPath $RawRoot -Directory -ErrorAction SilentlyContinue
foreach ($d in $existing) {
  if ($CanonicalClasses -contains $d.Name -or $SpecialFolders -contains $d.Name) {
    $report.ClassFolders += $d.Name
  } else {
    $report.UnknownFolders += $d.Name
  }
}

# Count + lint each folder
foreach ($folder in ($report.ClassFolders + $report.UnknownFolders)) {
  $path = Join-Path $RawRoot $folder
  $files = Get-ChildItem -LiteralPath $path -File -ErrorAction SilentlyContinue
  $report.TotalFiles += $files.Count

  $images = $files | Where-Object { $_.Extension.ToLower() -eq '.jpg' }
  $report.ClassCounts[$folder] = $images.Count
  $report.TotalImages += $images.Count

  # Lint non-image files
  foreach ($f in $files) {
    if ($f.Extension.ToLower() -ne '.jpg') {
      [void]$report.Violations.Add("not-jpg: $folder/$($f.Name)")
    }
  }

  # Lint image filenames
  foreach ($img in $images) {
    if ($img.Name -notmatch $NamePattern) {
      [void]$report.Violations.Add("bad-name: $folder/$($img.Name) (expected <class>__<tag>__<NNNN>.jpg)")
      continue
    }
    $matchedClass = $Matches[1]
    $matchedTag   = $Matches[2]
    # $matchedCounter = $Matches[3]  # reserved for future duplicate-counter checks

    if ($matchedClass -ne $folder) {
      [void]$report.Violations.Add(
        "class-mismatch: $folder/$($img.Name) (filename class '$matchedClass' != folder '$folder')"
      )
    }
    if ($AllowedTags -notcontains $matchedTag) {
      [void]$report.Violations.Add(
        "unknown-tag: $folder/$($img.Name) (tag '$matchedTag' not in allowed set)"
      )
    }
  }
}

# Progress vs Day-N targets
foreach ($cls in ($Targets.Keys | Sort-Object)) {
  $have = if ($report.ClassCounts.ContainsKey($cls)) { $report.ClassCounts[$cls] } else { 0 }
  $target = $Targets[$cls]
  $pct = if ($target -gt 0) { [math]::Round(100.0 * $have / $target, 0) } else { 0 }
  $report.Progress += [pscustomobject]@{
    Class   = $cls
    Have    = $have
    Target  = $target
    Percent = $pct
    Status  = if ($have -ge $target) { 'OK' } elseif ($have -ge ($target * 0.5)) { 'thin' } else { 'short' }
  }
}

# ---- Output ----

Write-Output ""
Write-Output "ToyVision raw dataset inspection"
Write-Output "================================="
Write-Output "Root        : $($report.Root)"
Write-Output "Day target  : $($report.Day)"
Write-Output "Total files : $($report.TotalFiles)"
Write-Output "Total images: $($report.TotalImages)"
Write-Output ""

Write-Output "Class folders present:"
foreach ($f in ($report.ClassFolders | Sort-Object)) {
  $count = if ($report.ClassCounts.ContainsKey($f)) { $report.ClassCounts[$f] } else { 0 }
  Write-Output ("  {0,-20} {1,5}" -f $f, $count)
}
if ($report.UnknownFolders.Count -gt 0) {
  Write-Output ""
  Write-Output "WARNING: unknown class folders under raw/ (rename or remove):"
  foreach ($u in $report.UnknownFolders) {
    Write-Output "  $u"
  }
}

Write-Output ""
Write-Output "Day $Day progress vs target:"
foreach ($p in $report.Progress) {
  $mark = switch ($p.Status) {
    'OK'    { 'OK   ' }
    'thin'  { 'THIN ' }
    'short' { 'SHORT' }
  }
  Write-Output ("  [$mark] {0,-20} {1,5}/{2,-5} {3,4}%" -f $p.Class, $p.Have, $p.Target, $p.Percent)
}

if ($report.Violations.Count -gt 0) {
  Write-Output ""
  Write-Output "Filename / structure violations:"
  foreach ($v in $report.Violations) {
    Write-Output "  - $v"
  }
} else {
  Write-Output ""
  Write-Output "No filename or structure violations found."
}

Write-Output ""
Write-Output "Reminder: this script does NOT validate image content or privacy."
Write-Output "Privacy review remains a manual gate before training."
Write-Output ""

# Exit code: 0 if no violations, 1 if violations exist.
if ($report.Violations.Count -gt 0) {
  exit 1
}
exit 0
