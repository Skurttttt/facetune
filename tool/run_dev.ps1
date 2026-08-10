$ErrorActionPreference = 'Stop'

$projectRoot = Split-Path -Parent $PSScriptRoot
$configPath = Join-Path $projectRoot 'config\development.json'

if (-not (Test-Path -LiteralPath $configPath)) {
  throw 'Missing config/development.json. Copy config/example.json and add the public Supabase client values.'
}

$configuration = Get-Content -Raw -LiteralPath $configPath | ConvertFrom-Json
$urlConfigured = -not [string]::IsNullOrWhiteSpace($configuration.SUPABASE_URL)
$keyConfigured = -not [string]::IsNullOrWhiteSpace($configuration.SUPABASE_PUBLISHABLE_KEY)

if (-not $urlConfigured -or -not $keyConfigured) {
  throw 'Supabase development configuration is incomplete.'
}
if ($configuration.SUPABASE_URL -notmatch '^https://[^/]+\.supabase\.co/?$') {
  throw 'SUPABASE_URL is not a valid Supabase project API URL.'
}
if ($configuration.SUPABASE_PUBLISHABLE_KEY -notlike 'sb_publishable_*') {
  throw 'SUPABASE_PUBLISHABLE_KEY is not a publishable client key.'
}

Write-Output 'Starting FaceTune with Supabase development configuration.'
Push-Location $projectRoot
try {
  flutter run "--dart-define-from-file=$configPath"
} finally {
  Pop-Location
}
