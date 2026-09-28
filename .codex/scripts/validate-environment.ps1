param()

$ErrorActionPreference = 'Stop'
$repoRoot = (Resolve-Path (Join-Path $PSScriptRoot '..\..')).Path
$errors = [System.Collections.Generic.List[string]]::new()
$warnings = [System.Collections.Generic.List[string]]::new()

function Require-Path {
    param([string]$RelativePath)
    $full = Join-Path $repoRoot $RelativePath
    if (-not (Test-Path -LiteralPath $full)) {
        $errors.Add("missing required path: $RelativePath")
    }
}

$required = @(
    'AGENTS.md',
    '.codex\README.md',
    '.codex\PROJECT.md',
    '.codex\ARCHITECTURE.md',
    '.codex\PRODUCT_RULES.md',
    '.codex\QUALITY_GATES.md',
    '.codex\DEVELOPMENT_WORKFLOW.md',
    '.codex\AUDIT.md',
    '.codex\CAPABILITIES.md',
    '.codex\DEMONSTRATION.md',
    '.codex\VALIDATION.md'
)
$required | ForEach-Object { Require-Path $_ }

$expectedAgents = @(
    'toy-vision-orchestrator', 'architect', 'perception-engineer',
    'yolo-debugger', 'tracking-engineer', 'false-collection-specialist',
    'gameplay-engineer', 'flutter-ui-engineer', 'animation-3d-engineer',
    'android-performance-engineer', 'test-engineer', 'adversarial-qa',
    'release-auditor'
)
foreach ($agent in $expectedAgents) {
    $relative = ".codex\agents\$agent.toml"
    Require-Path $relative
    $full = Join-Path $repoRoot $relative
    if (Test-Path -LiteralPath $full) {
        $text = Get-Content -LiteralPath $full -Raw
        foreach ($field in @('name', 'description', 'developer_instructions')) {
            if ($text -notmatch "(?m)^$field\s*=") {
                $errors.Add("$relative lacks required TOML field '$field'")
            }
        }
    }
}

$expectedSkills = @(
    'architecture-audit', 'perception-debugging', 'yolo-tflite-debugging',
    'toy-candidate-validation', 'tracking-reidentification',
    'disappearance-verification', 'false-collection-investigation',
    'scene-stability', 'flutter-gameplay-ui', 'rive-animation', 'gltf-3d',
    'performance-profiling', 'replay-testing', 'adversarial-testing',
    'clean-code-refactor', 'release-certification'
)
$skillNames = [System.Collections.Generic.HashSet[string]]::new()
foreach ($skill in $expectedSkills) {
    $relative = ".agents\skills\$skill\SKILL.md"
    Require-Path $relative
    $full = Join-Path $repoRoot $relative
    if (-not (Test-Path -LiteralPath $full)) { continue }
    $text = Get-Content -LiteralPath $full -Raw
    $nameMatch = [regex]::Match($text, '(?m)^name:\s*(.+)$')
    if (-not $nameMatch.Success) {
        $errors.Add("$relative lacks frontmatter name")
    } elseif (-not $skillNames.Add($nameMatch.Groups[1].Value.Trim())) {
        $errors.Add("duplicate skill name: $($nameMatch.Groups[1].Value.Trim())")
    }
    if ($text -notmatch '(?m)^description:\s*\S') {
        $errors.Add("$relative lacks frontmatter description")
    }
    foreach ($section in @(
        'PURPOSE', 'WHEN TO USE', 'INPUTS', 'PROCEDURE', 'TOOLS',
        'EXPECTED OUTPUT', 'FAILURE CONDITIONS', 'QUALITY GATES'
    )) {
        if ($text -notmatch "(?m)^# $([regex]::Escape($section))\s*$") {
            $errors.Add("$relative lacks section '$section'")
        }
    }
}

$expectedCommands = @(
    'audit', 'diagnose-perception', 'diagnose-false-positive',
    'diagnose-auto-collection', 'test-core', 'test-gameplay',
    'test-adversarial', 'profile', 'validate-architecture', 'certify'
)
foreach ($command in $expectedCommands) {
    $relative = ".codex\commands\$command.md"
    Require-Path $relative
}

$knownSkillNames = @($skillNames)
$commandFiles = Get-ChildItem -LiteralPath (Join-Path $repoRoot '.codex\commands') -Filter '*.md'
foreach ($commandFile in $commandFiles) {
    $text = Get-Content -LiteralPath $commandFile.FullName -Raw
    foreach ($match in [regex]::Matches($text, '\$(toyvision-[a-z0-9-]+)')) {
        $referenced = $match.Groups[1].Value
        if ($knownSkillNames -notcontains $referenced) {
            $errors.Add("$($commandFile.Name) references unknown skill '$referenced'")
        }
    }
}

$markdownFiles = @(
    Get-ChildItem -LiteralPath (Join-Path $repoRoot '.codex') -Recurse -Filter '*.md'
    Get-ChildItem -LiteralPath (Join-Path $repoRoot '.agents\skills') -Recurse -Filter '*.md'
)
foreach ($markdown in $markdownFiles) {
    $text = Get-Content -LiteralPath $markdown.FullName -Raw
    foreach ($match in [regex]::Matches($text, '\[[^\]]+\]\(([^)]+)\)')) {
        $target = $match.Groups[1].Value.Trim().Split('#')[0]
        if ([string]::IsNullOrWhiteSpace($target) -or
            $target -match '^(https?://|mailto:)' -or
            $target.StartsWith('#')) {
            continue
        }
        $resolved = Join-Path $markdown.DirectoryName $target
        if (-not (Test-Path -LiteralPath $resolved)) {
            $errors.Add("broken link in $($markdown.FullName.Substring($repoRoot.Length + 1)): $target")
        }
    }
}

$eventMatches = Select-String -Path (Join-Path $repoRoot 'lib\**\*.dart') -Pattern 'ToyCollected\('
foreach ($match in $eventMatches) {
    $relative = $match.Path.Substring($repoRoot.Length + 1).Replace('/', '\')
    $allowed = $relative -in @(
        'lib\application\cleanup\cleanup_session_service.dart',
        'lib\application\observability\session_evidence.dart',
        'lib\domain\cleanup\cleanup_event.dart'
    )
    if (-not $allowed) {
        $errors.Add("unexpected production ToyCollected reference: ${relative}:$($match.LineNumber)")
    }
}

if (-not (Test-Path -LiteralPath (Join-Path $repoRoot 'integration_test'))) {
    $warnings.Add('integration_test/ is absent; current integration tests are host-side under test/integration')
}

Write-Output "Toy Vision Codex environment validation"
Write-Output "  agents: $($expectedAgents.Count)"
Write-Output "  skills: $($expectedSkills.Count)"
Write-Output "  command recipes: $($expectedCommands.Count)"
Write-Output "  warnings: $($warnings.Count)"
$warnings | ForEach-Object { Write-Output "WARN: $_" }

if ($errors.Count -gt 0) {
    $errors | ForEach-Object { Write-Error $_ }
    exit 1
}

Write-Output 'PASS: structure, manifests, sections, links, command routing, and ToyCollected ownership are valid.'
exit 0
