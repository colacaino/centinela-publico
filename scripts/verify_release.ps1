$ErrorActionPreference = 'Stop'
$workspace = Split-Path -Parent $PSScriptRoot
$properties = Join-Path $workspace 'android\key.properties'
if (-not (Test-Path -LiteralPath $properties)) {
    throw 'Falta android/key.properties. Copia el ejemplo y usa un keystore institucional fuera de Git.'
}

Push-Location $workspace
try {
    flutter build appbundle --release
    flutter build apk --release
    $sdkRoot = if ($env:ANDROID_HOME) { $env:ANDROID_HOME } else { Join-Path $env:LOCALAPPDATA 'Android\Sdk' }
    $signer = Get-ChildItem -Path (Join-Path $sdkRoot 'build-tools') -Recurse -Filter apksigner.bat |
        Sort-Object FullName -Descending | Select-Object -First 1
    if (-not $signer) { throw 'No se encontró apksigner en Android SDK.' }
    & $signer.FullName verify --verbose --print-certs 'build\app\outputs\flutter-apk\app-release.apk'
    if ($LASTEXITCODE -ne 0) { throw 'El APK release no posee una firma verificable.' }
    Get-FileHash 'build\app\outputs\flutter-apk\app-release.apk' -Algorithm SHA256
    Get-FileHash 'build\app\outputs\bundle\release\app-release.aab' -Algorithm SHA256
} finally {
    Pop-Location
}
