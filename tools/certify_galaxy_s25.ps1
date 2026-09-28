param(
    [int]$MonitorSeconds = 900,
    [switch]$UseGpu,
    [switch]$IUnderstandFramesAreStored
)

$ErrorActionPreference = 'Stop'
$packageName = 'com.example.toyvision_realtime'
$workspace = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path
$flutter = 'C:\DevTools\flutter\bin\flutter.bat'
$dartBin = 'C:\DevTools\flutter\bin\cache\dart-sdk\bin'
$adb = Join-Path $env:LOCALAPPDATA 'Android\sdk\platform-tools\adb.exe'

function Get-Percentile {
    param([double[]]$Values, [double]$Quantile)
    if ($null -eq $Values -or $Values.Count -eq 0) { return $null }
    $sorted = @($Values | Sort-Object)
    $index = [Math]::Max(0, [Math]::Min($sorted.Count - 1, [Math]::Ceiling($Quantile * $sorted.Count) - 1))
    return [Math]::Round($sorted[$index], 3)
}

function Get-DumpsysNumber {
    param([string]$Path, [string]$Name)
    if (-not (Test-Path -LiteralPath $Path)) { return $null }
    $match = Select-String -LiteralPath $Path -Pattern "^\s*$Name\s*:\s*(-?\d+)" | Select-Object -First 1
    if ($null -eq $match) { return $null }
    return [int64]$match.Matches[0].Groups[1].Value
}

function Get-TextFingerprint {
    param([string]$Value)
    $sha = [System.Security.Cryptography.SHA256]::Create()
    try {
        $bytes = [System.Text.Encoding]::UTF8.GetBytes($Value)
        return ([BitConverter]::ToString($sha.ComputeHash($bytes))).Replace('-', '').Substring(0, 12)
    }
    finally {
        $sha.Dispose()
    }
}

if (-not $IUnderstandFramesAreStored) {
    Write-Error 'Certification stores camera frames as development dataset. Re-run with -IUnderstandFramesAreStored after confirming consent and scene privacy.'
}
if (-not (Test-Path -LiteralPath $flutter)) {
    Write-Error "Flutter not found at $flutter"
}
if (-not (Test-Path -LiteralPath $adb)) {
    Write-Error "ADB not found at $adb"
}

$deviceLines = @(& $adb devices | Select-Object -Skip 1 | Where-Object { $_ -match '\sdevice$' })
if ($deviceLines.Count -ne 1) {
    $status = [ordered]@{
        status = 'BLOCKED_PHYSICAL_DEVICE'
        detectedDevices = @($deviceLines)
        checkedAt = (Get-Date).ToUniversalTime().ToString('o')
        remediation = 'Enable Developer options and USB debugging, connect one unlocked Galaxy S25, accept the RSA prompt, then run adb devices.'
    }
    $status | ConvertTo-Json -Depth 5 | Set-Content -LiteralPath (Join-Path $workspace 'certification\latest_device_status.json')
    Write-Host ($status | ConvertTo-Json -Depth 5)
    exit 2
}

$serial = (($deviceLines[0] -split '\s+')[0])
$serialFingerprint = Get-TextFingerprint $serial
$model = (& $adb -s $serial shell getprop ro.product.model).Trim()
$device = (& $adb -s $serial shell getprop ro.product.device).Trim()
if ($model -notmatch 'SM-S93|Galaxy S25') {
    $status = [ordered]@{
        status = 'BLOCKED_PHYSICAL_DEVICE_WRONG_MODEL'
        serialFingerprint = $serialFingerprint
        connectedModel = $model
        connectedDevice = $device
        requiredModel = 'Galaxy S25 family (SM-S93*)'
        checkedAt = (Get-Date).ToUniversalTime().ToString('o')
        remediation = 'Disconnect this device, connect one unlocked Galaxy S25 with USB debugging enabled, accept the RSA prompt, then rerun this command.'
    }
    $status | ConvertTo-Json -Depth 5 | Set-Content -LiteralPath (Join-Path $workspace 'certification\latest_device_status.json')
    Write-Host ($status | ConvertTo-Json -Depth 5)
    exit 2
}

$stamp = (Get-Date).ToUniversalTime().ToString('yyyyMMddTHHmmssZ')
$runDirectory = Join-Path $workspace "certification\runs\$stamp"
New-Item -ItemType Directory -Path $runDirectory -Force | Out-Null
$env:Path = "C:\DevTools\flutter\bin;$dartBin;$env:Path"
$monitorJob = $null
$logcat = $null

$gpuValue = if ($UseGpu) { 'true' } else { 'false' }
Push-Location $workspace
try {
    & $flutter build apk --release `
        --dart-define=TOYVISION_CAPTURE=true `
        --dart-define=TOYVISION_CAPTURE_FRAMES=true `
        --dart-define=TOYVISION_CAPTURE_SCENARIO=galaxy_s25_certification `
        --dart-define=TOYVISION_USE_GPU=$gpuValue
    if ($LASTEXITCODE -ne 0) { throw 'Release build failed' }

    $apk = Join-Path $workspace 'build\app\outputs\flutter-apk\app-release.apk'
    & $adb -s $serial install -r $apk
    if ($LASTEXITCODE -ne 0) { throw 'APK install failed' }
    & $adb -s $serial shell pm grant $packageName android.permission.CAMERA
    & $adb -s $serial logcat -c

    $logcatOut = Join-Path $runDirectory 'logcat.txt'
    $logcatErr = Join-Path $runDirectory 'logcat.error.txt'
    $logcat = Start-Process -FilePath $adb -ArgumentList @('-s', $serial, 'logcat', '-v', 'threadtime') -RedirectStandardOutput $logcatOut -RedirectStandardError $logcatErr -WindowStyle Hidden -PassThru

    & $adb -s $serial shell am force-stop $packageName
    & $adb -s $serial shell am start -n "$packageName/.MainActivity"
    Start-Sleep -Seconds 5

    $deviceProperties = [ordered]@{
        model = $model
        device = $device
        serialFingerprint = $serialFingerprint
        androidRelease = (& $adb -s $serial shell getprop ro.build.version.release).Trim()
        sdk = (& $adb -s $serial shell getprop ro.build.version.sdk).Trim()
        securityPatch = (& $adb -s $serial shell getprop ro.build.version.security_patch).Trim()
        buildFingerprint = (& $adb -s $serial shell getprop ro.build.fingerprint).Trim()
        socModel = (& $adb -s $serial shell getprop ro.soc.model).Trim()
        hardware = (& $adb -s $serial shell getprop ro.hardware).Trim()
        egl = (& $adb -s $serial shell getprop ro.hardware.egl).Trim()
    }
    $deviceProperties | ConvertTo-Json | Set-Content -LiteralPath (Join-Path $runDirectory 'device_properties.json')
    & $adb -s $serial shell dumpsys SurfaceFlinger | Set-Content -LiteralPath (Join-Path $runDirectory 'surface_flinger.txt')
    & $adb -s $serial shell cmd gpu vkjson | Set-Content -LiteralPath (Join-Path $runDirectory 'vulkan_capabilities.json')
    & $adb -s $serial shell dumpsys media.camera | Set-Content -LiteralPath (Join-Path $runDirectory 'camera_service.txt')
    & $adb -s $serial shell dumpsys battery | Set-Content -LiteralPath (Join-Path $runDirectory 'battery_before.txt')
    & $adb -s $serial shell dumpsys thermalservice | Set-Content -LiteralPath (Join-Path $runDirectory 'thermal_before.txt')
    & $adb -s $serial shell dumpsys meminfo $packageName | Set-Content -LiteralPath (Join-Path $runDirectory 'meminfo_before.txt')

    $monitorFile = Join-Path $runDirectory 'device_monitor.jsonl'
    $monitorJob = Start-Job -ArgumentList $adb, $serial, $packageName, $monitorFile, $MonitorSeconds -ScriptBlock {
        param($adbPath, $deviceSerial, $appPackage, $outputFile, $duration)
        $started = Get-Date
        while (((Get-Date) - $started).TotalSeconds -lt $duration) {
            $pidValue = (& $adbPath -s $deviceSerial shell pidof $appPackage).Trim()
            $battery = (& $adbPath -s $deviceSerial shell dumpsys battery) -join "`n"
            $thermal = (& $adbPath -s $deviceSerial shell dumpsys thermalservice) -join "`n"
            $memory = if ($pidValue) { ((& $adbPath -s $deviceSerial shell dumpsys meminfo $appPackage) -join "`n") } else { '' }
            $cpu = if ($pidValue) { ((& $adbPath -s $deviceSerial shell top -b -n 1 -p $pidValue) -join "`n") } else { '' }
            [ordered]@{
                timestamp = (Get-Date).ToUniversalTime().ToString('o')
                pid = $pidValue
                battery = $battery
                thermal = $thermal
                memory = $memory
                cpu = $cpu
            } | ConvertTo-Json -Compress | Add-Content -LiteralPath $outputFile
            Start-Sleep -Seconds 5
        }
    }

    Write-Host ''
    Write-Host 'PHYSICAL ACCEPTANCE PROTOCOL'
    Write-Host '1. Open Cleanup and scan stable toys for at least 4 seconds.'
    Write-Host '2. Confirm gyro, acceleration and orientation update in Developer Vision Debug.'
    Write-Host '3. Rotate about 70 degrees: the target must become temporarilyLost, never collected.'
    Write-Host '4. Return to the toy after the rotation: the same identity must be reacquired.'
    Write-Host '5. Occlude a toy with a hand and reveal it: identity must remain.'
    Write-Host '6. Remove one toy from a stable view: background reveal must lead to exactly one collection.'
    Write-Host '7. Confirm the next target appears automatically without a blocking Review screen.'
    Write-Host '8. After the last pickup, sweep left, center, right and floor following the guidance.'
    Write-Host '9. During that sweep, introduce a new stable toy: verification must return to cleaning.'
    Write-Host '10. Remove it and repeat the complete empty-room sweep: Celebration must occur once.'
    Write-Host '11. Exercise hard negatives, low light and motion blur without a false collection.'
    Read-Host 'Press Enter only after the complete protocol is finished'

    $camera = Read-Host 'Camera preview and live frame updates verified? (yes/no)'
    $tflite = Read-Host 'TFLite proposals observed from the bundled model? (yes/no)'
    $audio = Read-Host 'Audio heard correctly? (yes/no)'
    $haptics = Read-Host 'Haptics felt correctly? (yes/no)'
    $rive = Read-Host 'Rive/Lottie rewards rendered correctly? (yes/no)'
    $tobi = Read-Host 'Tobi glTF loaded and animated correctly? (yes/no)'
    $imu = Read-Host 'IMU debug values updated and high motion blocked collection? (yes/no)'
    $pickup = Read-Host 'Stable real pickup showed background reveal and advanced once? (yes/no)'
    $coverage = Read-Host 'Directional room coverage guidance completed all required sectors? (yes/no)'
    $rediscovery = Read-Host 'A new toy during room verification returned the game to cleaning? (yes/no)'
    $celebration = Read-Host 'A genuinely empty room emitted one completion and one celebration? (yes/no)'

    Stop-Job $monitorJob -ErrorAction SilentlyContinue
    Receive-Job $monitorJob -ErrorAction SilentlyContinue | Out-Null
    Remove-Job $monitorJob -Force -ErrorAction SilentlyContinue
    if (-not $logcat.HasExited) { Stop-Process -Id $logcat.Id -Force }

    & $adb -s $serial shell dumpsys battery | Set-Content -LiteralPath (Join-Path $runDirectory 'battery_after.txt')
    & $adb -s $serial shell dumpsys thermalservice | Set-Content -LiteralPath (Join-Path $runDirectory 'thermal_after.txt')
    & $adb -s $serial shell dumpsys meminfo $packageName | Set-Content -LiteralPath (Join-Path $runDirectory 'meminfo_after.txt')
    & $adb -s $serial shell dumpsys gfxinfo $packageName framestats | Set-Content -LiteralPath (Join-Path $runDirectory 'gfxinfo_framestats.txt')

    $captureDestination = Join-Path $runDirectory 'captures'
    New-Item -ItemType Directory -Path $captureDestination -Force | Out-Null
    & $adb -s $serial pull "/sdcard/Android/data/$packageName/files/toyvision_captures" $captureDestination

    $visualChecks = [ordered]@{
        camera = $camera
        tflite = $tflite
        audio = $audio
        haptics = $haptics
        riveLottie = $rive
        tobiGltf = $tobi
        imuFusion = $imu
        stablePickup = $pickup
        directionalCoverage = $coverage
        rediscoveryDuringVerification = $rediscovery
        singleCelebration = $celebration
    }
    $visualChecks | ConvertTo-Json | Set-Content -LiteralPath (Join-Path $runDirectory 'manual_checks.json')

    $nativeInference = [System.Collections.Generic.List[double]]::new()
    $nativeFps = [System.Collections.Generic.List[double]]::new()
    $analysis = [System.Collections.Generic.List[double]]::new()
    $fusion = [System.Collections.Generic.List[double]]::new()
    $tracking = [System.Collections.Generic.List[double]]::new()
    Get-ChildItem -LiteralPath $captureDestination -Filter 'frames.jsonl' -Recurse | ForEach-Object {
        Get-Content -LiteralPath $_.FullName | ForEach-Object {
            if ([string]::IsNullOrWhiteSpace($_)) { return }
            $record = $_ | ConvertFrom-Json
            if ($null -ne $record.latency.nativeInferenceMs) { $nativeInference.Add([double]$record.latency.nativeInferenceMs) }
            if ($null -ne $record.latency.nativeFps) { $nativeFps.Add([double]$record.latency.nativeFps) }
            if ($null -ne $record.latency.analysisUs) { $analysis.Add([double]$record.latency.analysisUs / 1000.0) }
            if ($null -ne $record.latency.fusionUs) { $fusion.Add([double]$record.latency.fusionUs / 1000.0) }
            if ($null -ne $record.latency.trackingUs) { $tracking.Add([double]$record.latency.trackingUs / 1000.0) }
        }
    }
    $delegateEvidence = @(Select-String -LiteralPath $logcatOut -Pattern 'GPU delegate|TfLiteGpuDelegate|XNNPACK delegate|TensorFlow Lite' | Select-Object -ExpandProperty Line)
    $batteryBefore = Join-Path $runDirectory 'battery_before.txt'
    $batteryAfter = Join-Path $runDirectory 'battery_after.txt'
    $performance = [ordered]@{
        status = if ($nativeInference.Count -gt 0) { 'MEASURED' } else { 'NO_CAPTURED_FRAMES' }
        capturedFrames = $nativeInference.Count
        nativeInferenceMs = [ordered]@{
            p50 = Get-Percentile $nativeInference.ToArray() 0.50
            p95 = Get-Percentile $nativeInference.ToArray() 0.95
            p99 = Get-Percentile $nativeInference.ToArray() 0.99
        }
        nativeFps = [ordered]@{
            p50 = Get-Percentile $nativeFps.ToArray() 0.50
            p95 = Get-Percentile $nativeFps.ToArray() 0.95
            p99 = Get-Percentile $nativeFps.ToArray() 0.99
        }
        applicationStagesMs = [ordered]@{
            analysisP95 = Get-Percentile $analysis.ToArray() 0.95
            fusionP95 = Get-Percentile $fusion.ToArray() 0.95
            trackingP95 = Get-Percentile $tracking.ToArray() 0.95
        }
        battery = [ordered]@{
            levelBefore = Get-DumpsysNumber $batteryBefore 'level'
            levelAfter = Get-DumpsysNumber $batteryAfter 'level'
            temperatureTenthsCBefore = Get-DumpsysNumber $batteryBefore 'temperature'
            temperatureTenthsCAfter = Get-DumpsysNumber $batteryAfter 'temperature'
        }
        gpuRequested = [bool]$UseGpu
        delegateEvidence = $delegateEvidence
        rawDeviceMonitor = 'device_monitor.jsonl'
        rawMemoryAfter = 'meminfo_after.txt'
        rawThermalBefore = 'thermal_before.txt'
        rawThermalAfter = 'thermal_after.txt'
        rawFrameStats = 'gfxinfo_framestats.txt'
    }
    $performance | ConvertTo-Json -Depth 8 | Set-Content -LiteralPath (Join-Path $runDirectory 'performance_summary.json')

    $summary = [ordered]@{
        status = 'CAPTURE_COMPLETE_ANNOTATION_REQUIRED'
        serialFingerprint = $serialFingerprint
        model = $model
        device = $device
        gpuRequested = [bool]$UseGpu
        capturedFrames = $nativeInference.Count
        performanceEvidence = (Join-Path $runDirectory 'performance_summary.json')
        apkSha256 = (Get-FileHash $apk -Algorithm SHA256).Hash
        runDirectory = $runDirectory
        next = 'Create COMPLETE annotations and dataset.json, then run: flutter pub run tools/toyvision_certify.dart evaluate <dataset.json> <output-dir>'
    }
    $summary | ConvertTo-Json -Depth 5 | Set-Content -LiteralPath (Join-Path $runDirectory 'physical_run.json')
    Write-Host ($summary | ConvertTo-Json -Depth 5)
}
finally {
    if ($null -ne $monitorJob) {
        Stop-Job $monitorJob -ErrorAction SilentlyContinue
        Receive-Job $monitorJob -ErrorAction SilentlyContinue | Out-Null
        Remove-Job $monitorJob -Force -ErrorAction SilentlyContinue
    }
    if ($null -ne $logcat -and -not $logcat.HasExited) {
        Stop-Process -Id $logcat.Id -Force -ErrorAction SilentlyContinue
    }
    Pop-Location
}
