# Post-provision script to configure apphost.settings.json
# This script reads environment variables from azd and populates the apphost.settings.json file

$ErrorActionPreference = "Stop"

Write-Host "Configuring apphost.settings.json..." -ForegroundColor Green

# Get the root directory (two levels up from the script)
$ROOT_DIR = Split-Path -Parent (Split-Path -Parent $PSScriptRoot)
$SETTINGS_FILE = Join-Path $ROOT_DIR "apphost.settings.json"
$TEMPLATE_FILE = Join-Path $ROOT_DIR "apphost.settings.template.json"

# Check if settings file exists, if not, copy from template
if (-not (Test-Path $SETTINGS_FILE)) {
    Write-Host "apphost.settings.json not found. Copying from template..." -ForegroundColor Yellow
    if (Test-Path $TEMPLATE_FILE) {
        Copy-Item $TEMPLATE_FILE $SETTINGS_FILE
        Write-Host "Template copied successfully." -ForegroundColor Green
    } else {
        Write-Host "Error: Template file not found at $TEMPLATE_FILE" -ForegroundColor Red
        exit 1
    }
}

# Read environment variables from azd
$azdEnvOutput = azd env get-values
$envVars = @{}
foreach ($line in $azdEnvOutput) {
    if ($line -match '^([^=]+)=(.*)$') {
        $envVars[$matches[1]] = $matches[2] -replace '^"?(.*?)"?$', '$1'
    }
}

$OPENAI_ENDPOINT = if ($envVars.ContainsKey('AZURE_OPENAI_ENDPOINT')) { $envVars['AZURE_OPENAI_ENDPOINT'] } else { "" }
$OPENAI_DEPLOYMENT = if ($envVars.ContainsKey('AZURE_OPENAI_DEPLOYMENT_NAME')) { $envVars['AZURE_OPENAI_DEPLOYMENT_NAME'] } else { "" }

# Validate required variables
if ([string]::IsNullOrEmpty($OPENAI_ENDPOINT)) {
    Write-Host "Warning: AZURE_OPENAI_ENDPOINT environment variable is not set" -ForegroundColor Yellow
    $OPENAI_ENDPOINT = ""
}

if ([string]::IsNullOrEmpty($OPENAI_DEPLOYMENT)) {
    Write-Host "Warning: AZURE_OPENAI_DEPLOYMENT_NAME environment variable is not set" -ForegroundColor Yellow
    $OPENAI_DEPLOYMENT = ""
}

# Update the settings file
try {
    $settingsContent = Get-Content $SETTINGS_FILE -Raw | ConvertFrom-Json
    $settingsContent.Parameters.openAiEndpoint = $OPENAI_ENDPOINT
    $settingsContent.Parameters.openAiDeployment = $OPENAI_DEPLOYMENT
    $settingsContent | ConvertTo-Json -Depth 10 | Set-Content $SETTINGS_FILE
} catch {
    Write-Host "Error updating settings file: $_" -ForegroundColor Red
    exit 1
}

Write-Host "apphost.settings.json configured successfully!" -ForegroundColor Green
Write-Host "  - OpenAI Endpoint: $OPENAI_ENDPOINT" -ForegroundColor Cyan
Write-Host "  - OpenAI Deployment: $OPENAI_DEPLOYMENT" -ForegroundColor Cyan
