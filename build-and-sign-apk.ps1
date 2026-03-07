# ===================================================================
# AUTOMATED SCRIPT: Build and Sign a Release APK (Windows PowerShell)
# ===================================================================
# Set the keystore password via environment variable so it is NOT stored in this file:
#   $env:WMM_KEYSTORE_PASSWORD = "YOUR_PASSWORD"
# Then run: .\build-and-sign-apk.ps1
# ===================================================================

$ErrorActionPreference = "Stop"
$ProjectRoot = $PSScriptRoot
$AndroidApp = Join-Path $ProjectRoot "android\app"
$AndroidDir = Join-Path $ProjectRoot "android"
$KeystorePath = Join-Path $AndroidApp "upload-keystore.jks"
$KeyPropsPath = Join-Path $AndroidDir "key.properties"

$Pass = $env:WMM_KEYSTORE_PASSWORD
if (-not $Pass) {
    Write-Host "ERROR: Set the keystore password first:" -ForegroundColor Red
    Write-Host '  $env:WMM_KEYSTORE_PASSWORD = "YOUR_PASSWORD"' -ForegroundColor Yellow
    Write-Host "Then run this script again. Do not commit the password." -ForegroundColor Yellow
    exit 1
}

# --- STEP 1: GENERATE SIGNING KEY (if not exists) ---
Write-Host ""
Write-Host "-------------------------------------------------------------------" -ForegroundColor Cyan
Write-Host "STEP 1: SIGNING KEY" -ForegroundColor Cyan
Write-Host "-------------------------------------------------------------------" -ForegroundColor Cyan

if (-not (Test-Path $KeystorePath)) {
    Write-Host "Generating upload-keystore.jks in android\app ..."
    Push-Location $AndroidApp
    try {
        keytool -genkey -v `
            -keystore upload-keystore.jks `
            -keyalg RSA `
            -keysize 2048 `
            -validity 10000 `
            -alias upload `
            -storepass $Pass `
            -keypass $Pass `
            -dname "CN=Unknown, OU=Unknown, O=Unknown, L=Unknown, ST=Unknown, C=Unknown"
    } finally {
        Pop-Location
    }
    $Desktop = [Environment]::GetFolderPath("Desktop")
    $BackupPath = Join-Path $Desktop "upload-keystore-BACKUP.jks"
    Copy-Item $KeystorePath $BackupPath -Force
    Write-Host "Keystore created. A backup was placed on your Desktop. SAVE IT SECURELY." -ForegroundColor Green
} else {
    Write-Host "Keystore already exists. Skipping generation." -ForegroundColor Green
}

# --- STEP 2: CREATE KEY PROPERTIES FILE ---
Write-Host ""
Write-Host "-------------------------------------------------------------------" -ForegroundColor Cyan
Write-Host "STEP 2: KEY PROPERTIES FILE" -ForegroundColor Cyan
Write-Host "-------------------------------------------------------------------" -ForegroundColor Cyan

$KeyPropsContent = @"
storePassword=$Pass
keyPassword=$Pass
keyAlias=upload
storeFile=app/upload-keystore.jks
"@
Set-Content -Path $KeyPropsPath -Value $KeyPropsContent -Encoding UTF8
Write-Host "key.properties created in android\" -ForegroundColor Green

# --- STEP 3: BUILD RELEASE APK ---
Write-Host ""
Write-Host "-------------------------------------------------------------------" -ForegroundColor Cyan
Write-Host "STEP 3: BUILD RELEASE APK" -ForegroundColor Cyan
Write-Host "-------------------------------------------------------------------" -ForegroundColor Cyan
Write-Host "Building... (this may take a few minutes)" -ForegroundColor Yellow

Push-Location $ProjectRoot
try {
    flutter build apk --release
    if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }
} finally {
    Pop-Location
}

# --- DONE ---
Write-Host ""
Write-Host "-------------------------------------------------------------------" -ForegroundColor Green
Write-Host "BUILD COMPLETE!" -ForegroundColor Green
Write-Host "-------------------------------------------------------------------" -ForegroundColor Green
Write-Host "Signed release APK: build\app\outputs\flutter-apk\app-release.apk"
Write-Host ""
Write-Host "NEXT: Copy app-release.apk to your phone and install it."
Write-Host "REMINDER: Keep upload-keystore.jks and its password safe for future updates."
