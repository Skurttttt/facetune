$ErrorActionPreference = 'Stop'

$projectRoot = Split-Path -Parent $PSScriptRoot
$configPath = Join-Path $projectRoot 'config\development.json'
$apkPath = Join-Path $projectRoot 'build\app\outputs\flutter-apk\app-debug.apk'
$applicationId = 'com.example.facetune'

if (-not (Test-Path -LiteralPath $configPath)) {
  throw 'Missing config/development.json. Copy config/example.json and add the public client values.'
}

$configuration = Get-Content -Raw -LiteralPath $configPath | ConvertFrom-Json
$urlConfigured = -not [string]::IsNullOrWhiteSpace($configuration.SUPABASE_URL)
$keyConfigured = -not [string]::IsNullOrWhiteSpace($configuration.SUPABASE_PUBLISHABLE_KEY)

Write-Output "Supabase URL configured: $(if ($urlConfigured) { 'YES' } else { 'NO' })"
Write-Output "Supabase publishable key configured: $(if ($keyConfigured) { 'YES' } else { 'NO' })"

if (-not $urlConfigured -or -not $keyConfigured) {
  throw 'Supabase development configuration is incomplete.'
}
if ($configuration.SUPABASE_URL -notmatch '^https://[^/]+\.supabase\.co/?$') {
  throw 'SUPABASE_URL is not a valid Supabase project API URL.'
}
if ($configuration.SUPABASE_PUBLISHABLE_KEY -notlike 'sb_publishable_*') {
  throw 'SUPABASE_PUBLISHABLE_KEY is not a publishable client key.'
}

Push-Location $projectRoot
try {
  flutter build apk --debug --dart-define-from-file=$configPath

  $localProperties = Get-Content -LiteralPath 'android\local.properties'
  $sdkLine = $localProperties | Where-Object { $_ -like 'sdk.dir=*' } | Select-Object -First 1
  if (-not $sdkLine) {
    throw 'android/local.properties does not define sdk.dir.'
  }
  $sdkRoot = ($sdkLine.Substring('sdk.dir='.Length) -replace '\\', '\')
  $adbPath = Join-Path $sdkRoot 'platform-tools\adb.exe'
  if (-not (Test-Path -LiteralPath $adbPath)) {
    throw "adb.exe was not found at $adbPath"
  }

  $devices = & $adbPath devices
  $connected = @($devices | Select-String "`tdevice$")
  if ($connected.Count -eq 0) {
    Write-Output "Configured APK built at: $apkPath"
    throw 'No authorized Android device is connected. Enable USB debugging, reconnect, and rerun this script.'
  }

  & $adbPath install -r $apkPath
  if ($LASTEXITCODE -ne 0) {
    throw 'ADB installation failed.'
  }

  & $adbPath shell am force-stop $applicationId | Out-Null
  & $adbPath logcat -c
  & $adbPath shell monkey -p $applicationId -c android.intent.category.LAUNCHER 1 | Out-Null
  Start-Sleep -Seconds 4

  $startupLogs = & $adbPath logcat -d
  $initializationLine = $startupLogs |
    Select-String 'Supabase initialization: (READY|MISSINGCONFIGURATION|INVALIDCONFIGURATION|INITIALIZATIONFAILED)' |
    Select-Object -Last 1

  if (-not $initializationLine) {
    throw 'The APK installed, but no sanitized Supabase startup result was found in device logs.'
  }
  if ($initializationLine.Line -notmatch 'Supabase initialization: READY') {
    throw "Device runtime verification failed: $($initializationLine.Matches[0].Value)"
  }

  Write-Output 'Configured FaceTune APK installed successfully.'
  Write-Output 'Device runtime verification: Supabase initialization READY.'
} finally {
  Pop-Location
}
