<#
.SYNOPSIS
  Import one captured image from the camera roll into the right
  toyvision-dataset-v0_1/raw/<class>/ slot with the canonical naming.

.DESCRIPTION
  Phase 3.10 helper. Picks the next available <NNNN> counter for the
  given (class, scene-tag) pair, copies (or moves) the source file
  into raw/<class>/, and reports the new filename.

  Does NOT validate image content or privacy — that is your call before
  you point this script at a file. By default the source is copied (not
  moved) so a failed import does not delete the original. Pass -Move
  to move instead.

.PARAMETER ClassName
  One of the canonical 14 toy/ignored classes, the holding folder
  uncertain_review, or negative_only. Must match a folder under raw/.

.PARAMETER SceneTag
  One of: floor, bin, shelf, mixed, occluded, lowlight, topdown,
  closeup, farshot, lookalike, negative.

.PARAMETER SourceFile
  Path to the captured photo on disk (e.g. C:\Users\juanp\Pictures\
  S25-import\IMG_0042.jpg).

.PARAMETER Root
  Dataset root. Defaults to $HOME\toyvision-dataset-v0_1.

.PARAMETER Move
  If set, the source file is moved (not copied). Use only when you are
  confident in the (class, tag) choice — moving is harder to undo.

.PARAMETER WhatIf
  Show what would happen without writing anything.

.EXAMPLE
  pwsh tools/training/dataset/import_capture.ps1 `
    -ClassName toy_car -SceneTag floor `
    -SourceFile C:\Users\juanp\Pictures\S25-import\IMG_0042.jpg

  pwsh tools/training/dataset/import_capture.ps1 `
    -ClassName stuffed_animal -SceneTag shelf `
    -SourceFile $latestPhoto -Move
#>

[CmdletBinding(SupportsShouldProcess = $true)]
param(
  [Parameter(Mandatory = $true)]
  [string]$ClassName,

  [Parameter(Mandatory = $true)]
  [string]$SceneTag,

  [Parameter(Mandatory = $true)]
  [string]$SourceFile,

  [string]$Root = (Join-Path $HOME 'toyvision-dataset-v0_1'),

  [switch]$Move
)

$ErrorActionPreference = 'Stop'

$AllowedClasses = @(
  'toy_car','toy_truck','doll','stuffed_animal','building_blocks',
  'ball','action_figure','toy_train','puzzle','board_game',
  'not_toy','person_no_face','pet','book',
  'negative_only','uncertain_review'
)
$AllowedTags = @(
  'floor','bin','shelf','mixed','occluded','lowlight',
  'topdown','closeup','farshot','lookalike','negative'
)

if ($AllowedClasses -notcontains $ClassName) {
  Write-Error "ClassName '$ClassName' is not in the allowed set: $($AllowedClasses -join ', ')"
  exit 2
}
if ($AllowedTags -notcontains $SceneTag) {
  Write-Error "SceneTag '$SceneTag' is not in the allowed set: $($AllowedTags -join ', ')"
  exit 2
}

if (-not (Test-Path -LiteralPath $SourceFile)) {
  Write-Error "Source file not found: $SourceFile"
  exit 2
}

$src = Get-Item -LiteralPath $SourceFile
if ($src.Extension.ToLower() -ne '.jpg') {
  Write-Error "Source file must be .jpg (got '$($src.Extension)'). Convert before import."
  exit 2
}

$destDir = Join-Path (Join-Path $Root 'raw') $ClassName
if (-not (Test-Path -LiteralPath $destDir)) {
  Write-Error "Destination folder does not exist: $destDir`nCreate the dataset structure first."
  exit 2
}

# Find the next available counter for this (class, tag) pair.
$prefix = "${ClassName}__${SceneTag}__"
$existing = Get-ChildItem -LiteralPath $destDir -Filter "$prefix*.jpg" -File -ErrorAction SilentlyContinue
$maxCounter = 0
foreach ($f in $existing) {
  if ($f.Name -match '^[a-z_]+__[a-z]+__(\d{4})\.jpg$') {
    $n = [int]$Matches[1]
    if ($n -gt $maxCounter) { $maxCounter = $n }
  }
}
$nextCounter = $maxCounter + 1
if ($nextCounter -gt 9999) {
  Write-Error "Counter would exceed 9999 for ($ClassName, $SceneTag). Time to start a new prefix or move to a v0.2 dataset."
  exit 2
}

$destName = ('{0}__{1}__{2:D4}.jpg' -f $ClassName, $SceneTag, $nextCounter)
$destPath = Join-Path $destDir $destName

$action = if ($Move) { 'MOVE' } else { 'COPY' }
Write-Output ""
Write-Output "$action plan:"
Write-Output "  from: $($src.FullName)"
Write-Output "  to  : $destPath"
Write-Output ""

if ($PSCmdlet.ShouldProcess($destPath, $action)) {
  if ($Move) {
    Move-Item -LiteralPath $src.FullName -Destination $destPath
  } else {
    Copy-Item -LiteralPath $src.FullName -Destination $destPath
  }
  Write-Output "OK. Imported as: $destName"
}
