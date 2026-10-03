param(
    [switch]$WithEmulators,
    [switch]$WithAudit,
    [switch]$BuildDebug
)

$ErrorActionPreference = 'Stop'
$workspace = Split-Path -Parent $PSScriptRoot
Push-Location $workspace
try {
    dart format --output=none --set-exit-if-changed lib test
    flutter analyze
    flutter test
    Push-Location (Join-Path $workspace 'functions')
    try {
        npm ci
        npm run check
        if ($WithAudit) { npm run audit }
        if ($WithEmulators) { npm run test:emulator }
    } finally {
        Pop-Location
    }
    if ($BuildDebug) { flutter build apk --debug }
} finally {
    Pop-Location
}
