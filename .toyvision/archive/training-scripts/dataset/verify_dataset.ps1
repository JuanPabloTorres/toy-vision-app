<#
.SYNOPSIS
  Programmatic Gate A for the ToyVision dataset. Runs every structural
  check that should pass before training begins.

.DESCRIPTION
  Phase 3.10 / 3.9.3 helper. Combines:
    - Folder layout check (raw/, optional annotations/ + selected/).
    - Filename linting (inspect_raw.ps1's regex check).
    - Exact-duplicate check (detect_duplicates.ps1's SHA-1 sweep).
    - Annotation pairing check (every selected/<split>/<stem>.jpg has a
      matching annotations/<split>/<stem>.xml; only checked when those
      folders contain files).
    - Canonical-label-in-XML check (every <name> in every annotation is
      in the canonical 14-label set).

  This is the runnable mirror of Gate A in
  .toyvision/model-training/dataset-validation-checklist.md.

  Exit code:
    0  every gate passed.
    1  at least one gate failed; do not train.

.PARAMETER Root
  Dataset root. Defaults to $HOME\toyvision-dataset-v0_1.

.PARAMETER SkipDuplicates
  Skip the SHA-1 duplicate sweep (slow on large datasets). Default: false.

.EXAMPLE
  pwsh tools/training/dataset/verify_dataset.ps1
  pwsh tools/training/dataset/verify_dataset.ps1 -SkipDuplicates
#>

[CmdletBinding()]
param(
  [string]$Root = (Join-Path $HOME 'toyvision-dataset-v0_1'),
  [switch]$SkipDuplicates
)

$ErrorActionPreference = 'Stop'

$CanonicalToyClasses = @(
  'toy_car','toy_truck','doll','stuffed_animal','building_blocks',
  'ball','action_figure','toy_train','puzzle','board_game',
  'not_toy','person_no_face','pet','book'
)
$AllowedRawFolders = $CanonicalToyClasses + @('negative_only','uncertain_review')
$AllowedTags = @(
  'floor','bin','shelf','mixed','occluded','lowlight',
  'topdown','closeup','farshot','lookalike','negative'
)
$NamePattern = '^([a-z_]+)__([a-z]+)__(\d{4})\.jpg$'

$failures = New-Object System.Collections.Generic.List[string]
$passed = New-Object System.Collections.Generic.List[string]

function Report-Pass($msg) {
  $script:passed.Add($msg) | Out-Null
}
function Report-Fail($msg) {
  $script:failures.Add($msg) | Out-Null
}

# ---- Gate A.1: Folder layout ----

if (-not (Test-Path -LiteralPath $Root)) {
  Write-Error "Dataset root not found: $Root"
  exit 1
}
Report-Pass "root exists: $Root"

$rawRoot = Join-Path $Root 'raw'
if (-not (Test-Path -LiteralPath $rawRoot)) {
  Report-Fail "missing folder: raw/"
} else {
  Report-Pass "raw/ exists"
  $rawSubs = Get-ChildItem -LiteralPath $rawRoot -Directory | ForEach-Object Name
  foreach ($u in $rawSubs) {
    if ($AllowedRawFolders -notcontains $u) {
      Report-Fail "raw/ contains an unknown subfolder: '$u' (allowed: $($AllowedRawFolders -join ', '))"
    }
  }
}

# ---- Gate A.2: Filename lint ----

$rawImages = Get-ChildItem -LiteralPath $rawRoot -Recurse -File -ErrorAction SilentlyContinue
$violations = 0
foreach ($img in $rawImages) {
  $parentName = $img.Directory.Name
  if ($img.Extension.ToLower() -ne '.jpg') {
    Report-Fail "raw/${parentName}/$($img.Name): not a .jpg"
    $violations++
    continue
  }
  if ($img.Name -notmatch $NamePattern) {
    Report-Fail "raw/${parentName}/$($img.Name): filename does not match <class>__<tag>__<NNNN>.jpg"
    $violations++
    continue
  }
  $cls = $Matches[1]
  $tag = $Matches[2]
  if ($cls -ne $parentName) {
    Report-Fail "raw/${parentName}/$($img.Name): filename class '$cls' does not match folder"
    $violations++
  }
  if ($AllowedTags -notcontains $tag) {
    Report-Fail "raw/${parentName}/$($img.Name): unknown scene tag '$tag'"
    $violations++
  }
}
if ($rawImages.Count -gt 0 -and $violations -eq 0) {
  Report-Pass "filename lint passed across $($rawImages.Count) image(s)"
} elseif ($rawImages.Count -eq 0) {
  Report-Pass "filename lint skipped (no images yet)"
}

# ---- Gate A.3: Exact duplicates ----

if (-not $SkipDuplicates -and $rawImages.Count -gt 0) {
  $byHash = @{}
  foreach ($img in $rawImages) {
    $hash = (Get-FileHash -LiteralPath $img.FullName -Algorithm SHA1).Hash
    if (-not $byHash.ContainsKey($hash)) {
      $byHash[$hash] = @()
    }
    $byHash[$hash] += $img
  }
  $dupGroups = $byHash.GetEnumerator() | Where-Object { $_.Value.Count -gt 1 }
  if (@($dupGroups).Count -gt 0) {
    foreach ($g in $dupGroups) {
      $names = ($g.Value | ForEach-Object { $_.Directory.Name + '/' + $_.Name }) -join ', '
      Report-Fail "duplicate sha1 $($g.Key.Substring(0, 16))... shared by: $names"
    }
  } else {
    Report-Pass "no exact-bit duplicates across $($rawImages.Count) image(s)"
  }
} elseif ($SkipDuplicates) {
  Report-Pass "duplicate sweep skipped (-SkipDuplicates set)"
}

# ---- Gate A.4: Annotation pairing (only if annotations exist) ----

$annRoot = Join-Path $Root 'annotations'
$selRoot = Join-Path $Root 'selected'
$splits = @('train','val','test')

$pairsChecked = 0
foreach ($split in $splits) {
  $annDir = Join-Path $annRoot $split
  $selDir = Join-Path $selRoot $split
  if (-not (Test-Path -LiteralPath $annDir) -or -not (Test-Path -LiteralPath $selDir)) {
    continue
  }
  $selImgs = Get-ChildItem -LiteralPath $selDir -File -Filter '*.jpg' -ErrorAction SilentlyContinue
  $annXmls = Get-ChildItem -LiteralPath $annDir -File -Filter '*.xml' -ErrorAction SilentlyContinue
  if ($selImgs.Count -eq 0 -and $annXmls.Count -eq 0) {
    continue
  }

  $selStems = $selImgs | ForEach-Object { $_.BaseName } | Sort-Object
  $annStems = $annXmls | ForEach-Object { $_.BaseName } | Sort-Object
  $missing = $selStems | Where-Object { $_ -notin $annStems }
  $orphan  = $annStems | Where-Object { $_ -notin $selStems }
  foreach ($m in $missing) {
    Report-Fail "${split}: image '$m.jpg' has no matching annotation .xml"
  }
  foreach ($o in $orphan) {
    Report-Fail "${split}: annotation '$o.xml' has no matching image .jpg"
  }
  $pairsChecked += $selImgs.Count
}
if ($pairsChecked -gt 0) {
  Report-Pass "annotation pairing checked across $pairsChecked selected image(s)"
}

# ---- Gate A.5: Canonical labels in XML ----

$xmlsChecked = 0
$xmlLabelFails = 0
foreach ($split in $splits) {
  $annDir = Join-Path $annRoot $split
  if (-not (Test-Path -LiteralPath $annDir)) { continue }
  $xmls = Get-ChildItem -LiteralPath $annDir -File -Filter '*.xml' -ErrorAction SilentlyContinue
  foreach ($x in $xmls) {
    $xmlsChecked++
    try {
      [xml]$doc = Get-Content -LiteralPath $x.FullName -Raw
    } catch {
      Report-Fail "$split/$($x.Name): not valid XML"
      $xmlLabelFails++
      continue
    }
    $names = $doc.SelectNodes('//object/name') | ForEach-Object { $_.InnerText }
    foreach ($n in $names) {
      if ($CanonicalToyClasses -notcontains $n) {
        Report-Fail "$split/$($x.Name): non-canonical label '$n'"
        $xmlLabelFails++
      }
    }
  }
}
if ($xmlsChecked -gt 0 -and $xmlLabelFails -eq 0) {
  Report-Pass "all $xmlsChecked annotation(s) use canonical labels only"
}

# ---- Output ----

Write-Output ""
Write-Output "ToyVision dataset verification"
Write-Output "=============================="
Write-Output "Root: $Root"
Write-Output ""

Write-Output "Passed checks ($($passed.Count)):"
foreach ($p in $passed) { Write-Output "  [PASS] $p" }

if ($failures.Count -gt 0) {
  Write-Output ""
  Write-Output "Failed checks ($($failures.Count)):"
  foreach ($f in $failures) { Write-Output "  [FAIL] $f" }
}

Write-Output ""
if ($failures.Count -eq 0) {
  Write-Output "Overall: PASS"
  Write-Output ""
  exit 0
}
Write-Output "Overall: BLOCKED — fix the failures above before training."
Write-Output ""
exit 1
