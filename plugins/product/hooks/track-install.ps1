# Packmind plugin install tracking — PowerShell
# Fires on SessionStart; always exits 0 (never delays the session).

$ErrorActionPreference = 'SilentlyContinue'

$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$Sidecar = Join-Path $ScriptDir 'packmind-tracking.env'

if (-not (Test-Path $Sidecar)) { exit 0 }

# Load sidecar KEY=VALUE pairs
Get-Content $Sidecar | ForEach-Object {
    if ($_ -match '^([A-Z_]+)=(.*)$') {
        Set-Variable -Name $Matches[1] -Value $Matches[2] -Scope Script
    }
}

$PluginSlug = 'product'
# $MarketplaceName is read from the sidecar as $PACKMIND_MARKETPLACE_NAME
# to prevent shell injection from free-text marketplace names.
$MarketplaceName = $PACKMIND_MARKETPLACE_NAME

# ── 1. Scope detection (local → project → user; first match wins) ────────
$ProjectDir = if ($env:CLAUDE_PROJECT_DIR) { $env:CLAUDE_PROJECT_DIR } else { Get-Location }
$Scope = $null
# The enabledPlugins key is "<pluginName>@<marketplace>", where both names
# come from the client marketplace descriptor — not the Packmind slug /
# marketplace entity name in the sidecar. Derive them from CLAUDE_PLUGIN_ROOT
# (.../<marketplace>/<plugin>/<version>); fall back to the baked values.
$EnabledPluginName = $PluginSlug
$EnabledMarketplaceName = $MarketplaceName
if ($env:CLAUDE_PLUGIN_ROOT) {
    $PluginDir = Split-Path -Parent $env:CLAUDE_PLUGIN_ROOT
    $MarketplaceDir = Split-Path -Parent $PluginDir
    $EnabledPluginName = Split-Path -Leaf $PluginDir
    $EnabledMarketplaceName = Split-Path -Leaf $MarketplaceDir
}
$PluginKey = "$EnabledPluginName@$EnabledMarketplaceName"

# Installed version — read from the plugin manifest, fall back to the version
# segment of CLAUDE_PLUGIN_ROOT (.../<plugin>/<version>).
$InstalledVersion = $null
if ($env:CLAUDE_PLUGIN_ROOT) {
    $ManifestPath = Join-Path $env:CLAUDE_PLUGIN_ROOT '.claude-plugin\plugin.json'
    if (Test-Path $ManifestPath) {
        $Manifest = Get-Content $ManifestPath -Raw | ConvertFrom-Json
        if ($Manifest.version) { $InstalledVersion = $Manifest.version }
    }
    if (-not $InstalledVersion) { $InstalledVersion = Split-Path -Leaf $env:CLAUDE_PLUGIN_ROOT }
}

function Find-PluginScope {
    param([string]$FilePath)
    if (-not (Test-Path $FilePath)) { return $false }
    $Content = Get-Content $FilePath -Raw
    $Json = $Content | ConvertFrom-Json
    if ($Json.enabledPlugins -and $Json.enabledPlugins.PSObject.Properties.Name -contains $PluginKey) {
        return $true
    }
    return $false
}

# Extract a KEY=value from a flat .env file (parse-only; never sourced).
# Tolerates leading whitespace / `export `; strips one layer of quotes.
function Get-DotEnvValue {
    param([string]$FilePath, [string]$Key)
    if (-not (Test-Path $FilePath)) { return $null }
    foreach ($Line in Get-Content $FilePath) {
        if ($Line -match "^\s*(export\s+)?$Key=(.*)$") {
            $Val = $Matches[2].Trim()
            if ($Val.StartsWith('"') -and $Val.EndsWith('"')) { $Val = $Val.Trim('"') }
            elseif ($Val.StartsWith("'") -and $Val.EndsWith("'")) { $Val = $Val.Trim("'") }
            if ($Val) { return $Val }
        }
    }
    return $null
}

if (Find-PluginScope (Join-Path $ProjectDir '.claude\settings.local.json')) {
    $Scope = 'local'
} elseif (Find-PluginScope (Join-Path $ProjectDir '.claude\settings.json')) {
    $Scope = 'project'
} elseif (Find-PluginScope (Join-Path $HOME '.claude\settings.json')) {
    $Scope = 'user'
} else {
    exit 0
}

# ── 2. Repo detection (skipped for user scope — not repo-bound) ──────────
$RepoRemoteUrl = $null
if ($Scope -ne 'user') {
    $GitOutput = & git -C $ProjectDir remote get-url origin 2>$null
    if ($LASTEXITCODE -eq 0 -and $GitOutput) { $RepoRemoteUrl = $GitOutput.Trim() }
}

# ── 3. Identity resolution ───────────────────────────────────────────────
$AuthHeader = $null
$AnonIdHash = $null
$AnonEmailMasked = $null

# Packmind API key resolution order (same precedence as the CLI, plus a
# project .env between the env vars and the global credentials file):
#   PACKMIND_API_KEY env -> PACKMIND_API_KEY_V3 env
#   -> <project>/.env (PACKMIND_API_KEY, then PACKMIND_API_KEY_V3)
#   -> the ~/.packmind credentials file
$ApiKey = $null
if ($env:PACKMIND_API_KEY) {
    $ApiKey = $env:PACKMIND_API_KEY
} elseif ($env:PACKMIND_API_KEY_V3) {
    $ApiKey = $env:PACKMIND_API_KEY_V3
} else {
    $EnvFile = Join-Path $ProjectDir '.env'
    $ApiKey = Get-DotEnvValue $EnvFile 'PACKMIND_API_KEY'
    if (-not $ApiKey) { $ApiKey = Get-DotEnvValue $EnvFile 'PACKMIND_API_KEY_V3' }
    if (-not $ApiKey) {
        $CredsFile = Join-Path $HOME '.packmind\credentials.json'
        if (Test-Path $CredsFile) {
            $Creds = Get-Content $CredsFile -Raw | ConvertFrom-Json
            if ($Creds.apiKey) { $ApiKey = $Creds.apiKey }
        }
    }
}
if ($ApiKey) { $AuthHeader = "Bearer $ApiKey" }

# Claude account email → mask + hash
$ClaudeJson = Join-Path $HOME '.claude.json'
if (Test-Path $ClaudeJson) {
    $ClaudeData = Get-Content $ClaudeJson -Raw | ConvertFrom-Json
    $Email = $ClaudeData.oauthAccount.emailAddress
    if ($Email) {
        # Mask: first char of each local-part segment
        $Parts = $Email -split '@', 2
        $LocalPart = $Parts[0]
        $Domain = $Parts[1]
        $MaskedSegments = ($LocalPart -split '\.') | ForEach-Object {
            if ($_.Length -gt 0) { $_[0] + ('*' * ($_.Length - 1)) } else { '' }
        }
        $AnonEmailMasked = ($MaskedSegments -join '.') + '@' + $Domain

        # SHA-256 hash of lowercased email
        $EmailLower = $Email.ToLower()
        $Bytes = [System.Text.Encoding]::UTF8.GetBytes($EmailLower)
        $Hash = [System.Security.Cryptography.SHA256]::Create().ComputeHash($Bytes)
        $AnonIdHash = ($Hash | ForEach-Object { $_.ToString('x2') }) -join ''
    }
}

# ── 4. Build payload ─────────────────────────────────────────────────────
$Payload = @{
    pluginSlug    = $PluginSlug
    marketplaceName = $MarketplaceName
    scope         = $Scope
}
if ($InstalledVersion) { $Payload['installedVersion']     = $InstalledVersion }
if ($RepoRemoteUrl)   { $Payload['repoRemoteUrl']        = $RepoRemoteUrl }
if ($AnonIdHash)      { $Payload['anonymousIdHash']      = $AnonIdHash }
if ($AnonEmailMasked) { $Payload['anonymousEmailMasked'] = $AnonEmailMasked }

$Headers = @{
    'Content-Type'               = 'application/json'
    'X-Packmind-Tracking-Token'  = $PACKMIND_TRACKING_TOKEN
}
if ($AuthHeader) { $Headers['Authorization'] = $AuthHeader }

$Body = $Payload | ConvertTo-Json -Compress

# ── 5. POST heartbeat (backgrounded via Start-Job) ───────────────────────
$Url = "$PACKMIND_API_BASE_URL/tracking/plugin-installs"
Start-Job -ScriptBlock {
    param($Url, $Headers, $Body)
    Invoke-RestMethod -Method Post -Uri $Url -Headers $Headers -Body $Body -TimeoutSec 3 | Out-Null
} -ArgumentList $Url, $Headers, $Body | Out-Null

exit 0
