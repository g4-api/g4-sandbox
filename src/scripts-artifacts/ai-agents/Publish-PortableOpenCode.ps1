<#
.SYNOPSIS
    Packages a fully boxed, portable OpenCode runtime for both G4 agent
    partitions (g4-explorer, g4-orchestrator).

.DESCRIPTION
    Standalone deployment script extracted from Publish-G4Sandbox.ps1.

    - Resolves and verifies (SHA-256) the latest 'opencode' and 'ripgrep'
      GitHub release assets for the requested OS/architecture
    - Optionally resolves and downloads the private 'g4-api/g4-ai-assets'
      release (requires a GITHUB_TOKEN or GH_TOKEN environment variable);
      when no token is available, the box is still produced with empty
      agents/skills directories and a warning is emitted
    - Boxes OpenCode + ripgrep + selected agents/skills under
      '<stage>/ai-agents/partitions/<partition>/opencode'
    - Writes per-partition 'ai-assets.json' and 'opencode.json' config
    - Generates OS-specific launcher scripts (start.cmd/.sh, start-opencode.cmd/.sh)
      that box environment variables (HOME, APPDATA, XDG_*, etc.) so the
      runtime never touches locations outside the sandbox
    - Generates a sandbox-root launcher that defaults to 'g4-explorer' and
      accepts an explicit partition name as its first argument

    This script is fully self-contained: it embeds its own copies of the
    GitHub asset resolution/verification/extraction helpers, so it can run
    without depending on any other script in this repository.

.COMPATIBILITY
    - PowerShell 5.x (Windows)
    - PowerShell Core (Windows, Linux, macOS)

.ASSUMPTIONS
    - Network access to github.com and the GitHub API is available
    - tar is available on PATH for non-zip extractions when required
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)] [ValidateSet('Linux', 'Windows')] [string]$OperatingSystem,
    [Parameter(Mandatory = $true)] [string]$ArchiveDirectory,
    [Parameter(Mandatory = $true)] [string]$StageDirectory
)
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

# ---------------------------------------------------------------------------
# Function: Resolve-VerifiedGitHubAsset
# ---------------------------------------------------------------------------
function Resolve-VerifiedGitHubAsset {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)] [string]$Repository,
        [Parameter(Mandatory = $true)] [string]$AssetNameTemplate
    )

    $headers = @{
        Accept = "application/vnd.github+json"
        "User-Agent" = "g4-sandbox-builder"
        "X-GitHub-Api-Version" = "2022-11-28"
    }
    $release = Invoke-RestMethod `
        -Uri "https://api.github.com/repos/$Repository/releases/latest" `
        -Headers $headers `
        -Method Get `
        -UseBasicParsing

    if (-not $release.tag_name -or -not $release.assets) {
        throw "GitHub release metadata for '$Repository' is incomplete."
    }

    $versionMatch = [regex]::Match([string]$release.tag_name, '\d+(?:\.\d+)+(?:[-+][0-9A-Za-z.-]+)?')
    if (-not $versionMatch.Success) {
        throw "Could not parse a version from GitHub release tag '$($release.tag_name)'."
    }

    $assetName = $AssetNameTemplate -f $versionMatch.Value
    $asset = @($release.assets) | Where-Object { $_.name -eq $assetName } | Select-Object -First 1
    if (-not $asset) {
        throw "Asset '$assetName' was not found in release '$($release.tag_name)' of '$Repository'."
    }

    $digestProperty = $asset.PSObject.Properties["digest"]
    if (-not $digestProperty) {
        throw [System.Security.SecurityException]::new("Asset '$assetName' does not publish a SHA-256 digest.")
    }

    $digest = ([string]$digestProperty.Value).Trim().ToLowerInvariant() -replace '^sha256:', ''
    if ($digest -notmatch '^[0-9a-f]{64}$') {
        throw [System.Security.SecurityException]::new("Asset '$assetName' publishes an invalid SHA-256 digest.")
    }

    [pscustomobject]@{
        AssetName = $assetName
        DownloadUrl = [string]$asset.browser_download_url
        Headers = $headers
        Sha256 = $digest
        Tag = [string]$release.tag_name
    }
}

# ---------------------------------------------------------------------------
# Function: Receive-VerifiedGitHubAsset
# ---------------------------------------------------------------------------
function Receive-VerifiedGitHubAsset {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)] [object]$Asset,
        [Parameter(Mandatory = $true)] [string]$ArchiveDirectory
    )

    New-Item -ItemType Directory -Path $ArchiveDirectory -Force | Out-Null
    $archivePath = Join-Path $ArchiveDirectory $Asset.AssetName
    Write-Host "Downloading verified release asset: '$($Asset.AssetName)'" -ForegroundColor DarkGray
    Invoke-WebRequest `
        -Uri $Asset.DownloadUrl `
        -Headers $Asset.Headers `
        -OutFile $archivePath `
        -UseBasicParsing

    $actualHash = (Get-FileHash -LiteralPath $archivePath -Algorithm SHA256).Hash.ToLowerInvariant()
    if ($actualHash -ne $Asset.Sha256) {
        throw [System.Security.SecurityException]::new(
            "SHA-256 mismatch for '$($Asset.AssetName)'. Expected $($Asset.Sha256); received $actualHash.")
    }

    return $archivePath
}

# ---------------------------------------------------------------------------
# Function: Expand-PortableAgentArchive
# ---------------------------------------------------------------------------
function Expand-PortableAgentArchive {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)] [string]$ArchivePath,
        [Parameter(Mandatory = $true)] [string]$DestinationPath
    )

    New-Item -ItemType Directory -Path $DestinationPath -Force | Out-Null
    if ($ArchivePath.EndsWith('.zip', [System.StringComparison]::OrdinalIgnoreCase)) {
        Expand-Archive -LiteralPath $ArchivePath -DestinationPath $DestinationPath -Force
        return
    }

    $tar = Get-Command tar -ErrorAction SilentlyContinue
    if (-not $tar) {
        throw "Cannot extract '$ArchivePath' because tar is not available on PATH."
    }

    & $tar.Source -xf $ArchivePath -C $DestinationPath
    if ($LASTEXITCODE -ne 0) {
        throw "tar failed to extract '$ArchivePath' (exit code: $LASTEXITCODE)."
    }
}

# ---------------------------------------------------------------------------
# Function: Find-SingleExtractedExecutable
# ---------------------------------------------------------------------------
function Find-SingleExtractedExecutable {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)] [string]$ExtractionRoot,
        [Parameter(Mandatory = $true)] [string]$ExecutableName
    )

    $matches = @(Get-ChildItem -LiteralPath $ExtractionRoot -Recurse -Force -File |
        Where-Object { $_.Name -eq $ExecutableName })
    if ($matches.Count -ne 1) {
        throw "Expected exactly one '$ExecutableName' in '$ExtractionRoot'; found $($matches.Count)."
    }

    return $matches[0].FullName
}

# ---------------------------------------------------------------------------
# Function: Resolve-G4AiAssetsRelease
# ---------------------------------------------------------------------------
function Resolve-G4AiAssetsRelease {
    [CmdletBinding()]
    param([Parameter(Mandatory = $true)] [string]$Token)

    $headers = @{
        Accept = 'application/vnd.github+json'
        Authorization = "Bearer $Token"
        'User-Agent' = 'g4-sandbox-builder'
        'X-GitHub-Api-Version' = '2022-11-28'
    }
    $release = Invoke-RestMethod `
        -Uri 'https://api.github.com/repos/g4-api/g4-ai-assets/releases/latest' `
        -Headers $headers `
        -Method Get `
        -UseBasicParsing
    $assets = @($release.assets | Where-Object { ([string]$_.name) -match '(?i)^(skills|ai-assets).*\.zip$' })
    if ($assets.Count -ne 1) {
        throw "Latest g4-ai-assets release '$($release.tag_name)' must contain exactly one skills*.zip or ai-assets*.zip asset; found $($assets.Count)."
    }

    $asset = $assets[0]
    $digest = ([string]$asset.digest).Trim().ToLowerInvariant() -replace '^sha256:', ''
    if ($digest -notmatch '^[0-9a-f]{64}$') {
        throw [System.Security.SecurityException]::new("Asset '$($asset.name)' does not publish a valid SHA-256 digest.")
    }

    $downloadHeaders = $headers.Clone()
    $downloadHeaders.Accept = 'application/octet-stream'
    return [pscustomobject]@{
        AssetName = [string]$asset.name
        DownloadUrl = [string]$asset.url
        Headers = $downloadHeaders
        Sha256 = $digest
        Tag = [string]$release.tag_name
    }
}

# ---------------------------------------------------------------------------
# Function: Expand-VerifiedAiAssetsArchive
# ---------------------------------------------------------------------------
function Expand-VerifiedAiAssetsArchive {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)] [string]$ArchivePath,
        [Parameter(Mandatory = $true)] [string]$DestinationPath
    )

    Add-Type -AssemblyName System.IO.Compression
    Add-Type -AssemblyName System.IO.Compression.FileSystem
    New-Item -ItemType Directory -Path $DestinationPath -Force | Out-Null
    $destinationRoot = [System.IO.Path]::GetFullPath($DestinationPath).TrimEnd('\', '/') + [System.IO.Path]::DirectorySeparatorChar
    $archive = [System.IO.Compression.ZipFile]::OpenRead($ArchivePath)

    try {
        foreach ($entry in $archive.Entries) {
            $entryName = ([string]$entry.FullName).Replace('\', '/').TrimStart('/')
            if ([string]::IsNullOrWhiteSpace($entryName)) { continue }
            if ($entryName -match '(^|/)\.\.(/|$)' -or $entry.FullName.StartsWith('/') -or
                $entry.FullName.StartsWith('\') -or $entry.FullName -match '^[A-Za-z]:') {
                throw [System.IO.InvalidDataException]::new("Archive entry '$($entry.FullName)' escapes the extraction root.")
            }

            # The upper Unix mode bits identify symbolic links in archives produced on Unix.
            $unixMode = ($entry.ExternalAttributes -shr 16) -band 0xF000
            $dosAttributes = $entry.ExternalAttributes -band 0xFFFF
            if ($unixMode -eq 0xA000 -or ($dosAttributes -band [System.IO.FileAttributes]::ReparsePoint)) {
                throw [System.IO.InvalidDataException]::new("Archive entry '$($entry.FullName)' is a symbolic link.")
            }

            $destination = [System.IO.Path]::GetFullPath((Join-Path $DestinationPath $entryName))
            if (-not $destination.StartsWith($destinationRoot, [System.StringComparison]::OrdinalIgnoreCase)) {
                throw [System.IO.InvalidDataException]::new("Archive entry '$($entry.FullName)' escapes the extraction root.")
            }

            if ($entryName.EndsWith('/')) {
                New-Item -ItemType Directory -Path $destination -Force | Out-Null
                continue
            }

            $parent = Split-Path $destination -Parent
            New-Item -ItemType Directory -Path $parent -Force | Out-Null
            $sourceStream = $entry.Open()
            $destinationStream = [System.IO.File]::Open($destination, [System.IO.FileMode]::CreateNew)
            try { $sourceStream.CopyTo($destinationStream) }
            finally {
                $destinationStream.Dispose()
                $sourceStream.Dispose()
            }
        }
    }
    finally {
        $archive.Dispose()
    }
}

# ---------------------------------------------------------------------------
# Function: Get-G4AiAssetInventory
# ---------------------------------------------------------------------------
function Get-G4AiAssetInventory {
    [CmdletBinding()]
    param([Parameter(Mandatory = $true)] [string]$ExtractionRoot)

    $skillsRoot = Join-Path $ExtractionRoot 'skills'
    $agentsRoot = Join-Path $ExtractionRoot 'agents'
    if (-not (Test-Path -LiteralPath $skillsRoot -PathType Container) -or
        -not (Test-Path -LiteralPath $agentsRoot -PathType Container)) {
        throw 'The g4-ai-assets archive must contain top-level skills and agents directories.'
    }

    $unexpectedSkillFiles = @(Get-ChildItem -LiteralPath $skillsRoot -Force -File)
    if ($unexpectedSkillFiles.Count -gt 0) {
        throw "The g4-ai-assets skills root contains unexpected top-level files."
    }

    $skills = @{}
    foreach ($directory in @(Get-ChildItem -LiteralPath $skillsRoot -Force -Directory)) {
        if (-not (Test-Path -LiteralPath (Join-Path $directory.FullName 'SKILL.md') -PathType Leaf)) {
            Write-Warning "Skipping AI asset directory '$($directory.Name)' because it does not contain SKILL.md."
            continue
        }
        $key = $directory.Name.ToLowerInvariant()
        if ($skills.ContainsKey($key)) { throw "Duplicate skill '$($directory.Name)' in g4-ai-assets archive." }
        $skills[$key] = $directory
    }

    $agents = @{}
    foreach ($file in @(Get-ChildItem -LiteralPath $agentsRoot -Recurse -Force -File -Filter '*.md')) {
        $key = [System.IO.Path]::GetFileNameWithoutExtension($file.Name).ToLowerInvariant()
        if ($agents.ContainsKey($key)) { throw "Duplicate agent '$($file.Name)' in g4-ai-assets archive." }
        $agents[$key] = $file
    }

    return [pscustomobject]@{ Agents = $agents; Skills = $skills }
}

# ---------------------------------------------------------------------------
# Function: Copy-SelectedG4AiAssets
# ---------------------------------------------------------------------------
function Copy-SelectedG4AiAssets {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)] [object]$Inventory,
        [Parameter(Mandatory = $true)] [hashtable]$Manifest,
        [Parameter(Mandatory = $true)] [string]$PartitionRoot
    )

    $agentsDestination = Join-Path $PartitionRoot 'agents'
    $skillsDestination = Join-Path $PartitionRoot 'skills'
    New-Item -ItemType Directory -Path $agentsDestination -Force | Out-Null
    New-Item -ItemType Directory -Path $skillsDestination -Force | Out-Null

    $agentNames = @($Manifest.agents)
    if ($agentNames.Count -eq 0) { $agentNames = @($Inventory.Agents.Keys | Sort-Object) }
    foreach ($name in $agentNames) {
        $key = ([string]$name).ToLowerInvariant()
        if (-not $Inventory.Agents.ContainsKey($key)) {
            Write-Warning "Skipping agent '$name' because it was requested by ai-assets.json but is absent from the release."
            continue
        }
        Copy-Item -LiteralPath $Inventory.Agents[$key].FullName -Destination $agentsDestination -Force
    }

    $skillNames = @($Manifest.skills)
    if ($skillNames.Count -eq 0) { $skillNames = @($Inventory.Skills.Keys | Sort-Object) }
    foreach ($name in $skillNames) {
        $key = ([string]$name).ToLowerInvariant()
        if (-not $Inventory.Skills.ContainsKey($key)) {
            Write-Warning "Skipping skill '$name' because it was requested by ai-assets.json but is absent from the release."
            continue
        }
        Copy-Item -LiteralPath $Inventory.Skills[$key].FullName -Destination $skillsDestination -Recurse -Force
    }
}


$isWindowsTarget = $OperatingSystem -eq 'Windows'
$openCodeAssetName = if ($isWindowsTarget) { 'opencode-windows-x64.zip' } else { 'opencode-linux-x64.tar.gz' }
$ripgrepAssetTemplate = if ($isWindowsTarget) {
    'ripgrep-{0}-x86_64-pc-windows-msvc.zip'
}
else {
    'ripgrep-{0}-x86_64-unknown-linux-musl.tar.gz'
}
$executableName = if ($isWindowsTarget) { 'opencode.exe' } else { 'opencode' }
$ripgrepName = if ($isWindowsTarget) { 'rg.exe' } else { 'rg' }

$githubToken = [System.Environment]::GetEnvironmentVariable('GITHUB_TOKEN', 'Process')
if ([string]::IsNullOrWhiteSpace($githubToken)) {
    $githubToken = [System.Environment]::GetEnvironmentVariable('GH_TOKEN', 'Process')
}
if ([string]::IsNullOrWhiteSpace($githubToken)) {
    Write-Warning (
        'GITHUB_TOKEN and GH_TOKEN are not available. The sandbox will include OpenCode, ripgrep, ' +
        'partition configuration, AI-assets manifests, and empty agents/skills directories, but the ' +
        'private g4-ai-assets release will not be downloaded.')
}

$partitionManifests = @{
    'g4-explorer' = @{
        agents = @(
            'g4-explore-action', 'g4-explore-path-promoter', 'g4-explorer'
        )
        skills = @(
            'g4-explore-deploy-sandbox', 'g4-explore-promote-path', 'g4-explore-runtime',
            'g4-locator-finder', 'g4-register-template', 'g4-start-session-uia',
            'g4-visual-environment', 'g4-visual-ground', 'g4-visual-observe', 'g4-xpath-composer',
            'manifest-create', 'manifest-description', 'manifest-enrichment', 'manifest-examples',
            'manifest-final-review', 'manifest-parameters', 'manifest-pipeline', 'manifest-rag-qa',
            'manifest-summary'
        )
    }
    'g4-orchestrator' = @{
        agents = @(
            'g4-action-attempt', 'g4-action-tool-discovery', 'g4-action-tool-selector',
            'g4-capability-search', 'g4-execution-contract-validator', 'g4-intent-planner',
            'g4-orchestrator', 'g4-session-starter', 'g4-template-promoter'
        )
        skills = @(
            'g4-decompose-intent-to-actions', 'g4-deploy-sandbox', 'g4-execute-rule-by-intent',
            'g4-locator-finder', 'g4-maintain-session-journal', 'g4-orchestrate-user-intent',
            'g4-orchestrate-visual-grounding', 'g4-planner-execution-contract', 'g4-planner-worker-pool',
            'g4-promote-flow-to-template', 'g4-register-template', 'g4-run-action-attempt',
            'g4-start-session', 'g4-start-session-uia', 'g4-verify-action-result',
            'g4-visual-environment', 'g4-visual-ground', 'g4-visual-observe', 'g4-xpath-composer',
            'manifest-create', 'manifest-description', 'manifest-enrichment',
            'manifest-examples', 'manifest-final-review', 'manifest-parameters', 'manifest-pipeline',
            'manifest-rag-qa', 'manifest-summary', 'manifest-test-scripts'
        )
    }
}

$openCodeAsset = Resolve-VerifiedGitHubAsset `
    -Repository 'anomalyco/opencode' `
    -AssetNameTemplate $openCodeAssetName
$ripgrepAsset = Resolve-VerifiedGitHubAsset `
    -Repository 'BurntSushi/ripgrep' `
    -AssetNameTemplate $ripgrepAssetTemplate
$aiAssetsRelease = if (-not [string]::IsNullOrWhiteSpace($githubToken)) {
    Resolve-G4AiAssetsRelease -Token $githubToken
}
else {
    $null
}

$openCodeArchive = Receive-VerifiedGitHubAsset -Asset $openCodeAsset -ArchiveDirectory $ArchiveDirectory
$ripgrepArchive = Receive-VerifiedGitHubAsset -Asset $ripgrepAsset -ArchiveDirectory $ArchiveDirectory
$aiAssetsArchive = if ($null -ne $aiAssetsRelease) {
    Receive-VerifiedGitHubAsset -Asset $aiAssetsRelease -ArchiveDirectory $ArchiveDirectory
}
else {
    $null
}
$extractionRoot = Join-Path $ArchiveDirectory ('opencode-extract-' + [guid]::NewGuid().ToString('N'))
$openCodeExtraction = Join-Path $extractionRoot 'opencode'
$ripgrepExtraction = Join-Path $extractionRoot 'ripgrep'
$aiAssetsExtraction = Join-Path $extractionRoot 'ai-assets'

try {
    Expand-PortableAgentArchive -ArchivePath $openCodeArchive -DestinationPath $openCodeExtraction
    Expand-PortableAgentArchive -ArchivePath $ripgrepArchive -DestinationPath $ripgrepExtraction
    $openCodeExecutable = Find-SingleExtractedExecutable -ExtractionRoot $openCodeExtraction -ExecutableName $executableName
    $ripgrepExecutable = Find-SingleExtractedExecutable -ExtractionRoot $ripgrepExtraction -ExecutableName $ripgrepName
    $aiAssetsInventory = if ($null -ne $aiAssetsArchive) {
        Expand-VerifiedAiAssetsArchive -ArchivePath $aiAssetsArchive -DestinationPath $aiAssetsExtraction
        Get-G4AiAssetInventory -ExtractionRoot $aiAssetsExtraction
    }
    else {
        $null
    }

    $partitionsRoot = [System.IO.Path]::Combine($StageDirectory, 'ai-agents', 'partitions')
    foreach ($partitionName in @('g4-explorer', 'g4-orchestrator')) {
        $partitionRoot = Join-Path $partitionsRoot $partitionName
        $boxRoot = Join-Path $partitionRoot 'opencode'
        $binRoot = [System.IO.Path]::Combine($boxRoot, 'runtime', 'bin')
        $manifest = $partitionManifests[$partitionName]

        # A failed earlier build may have left stale boxed state under the disposable staging root.
        if (Test-Path -LiteralPath $partitionRoot) {
            Remove-Item -LiteralPath $partitionRoot -Recurse -Force
        }

        New-Item -ItemType Directory -Path $binRoot -Force | Out-Null
        Copy-Item -LiteralPath $openCodeExecutable -Destination (Join-Path $binRoot $executableName) -Force
        Copy-Item -LiteralPath $ripgrepExecutable -Destination (Join-Path $binRoot $ripgrepName) -Force
        if ($null -ne $aiAssetsInventory) {
            Copy-SelectedG4AiAssets -Inventory $aiAssetsInventory -Manifest $manifest -PartitionRoot $partitionRoot
        }
        else {
            New-Item -ItemType Directory -Path (Join-Path $partitionRoot 'agents') -Force | Out-Null
            New-Item -ItemType Directory -Path (Join-Path $partitionRoot 'skills') -Force | Out-Null
        }
        $manifest | ConvertTo-Json -Depth 4 | Set-Content -LiteralPath (Join-Path $partitionRoot 'ai-assets.json') -Encoding UTF8

        $config = [ordered]@{
            '$schema' = 'https://opencode.ai/config.json'
            model = 'local-gemma/gemma4'
            default_agent = $partitionName
            provider = [ordered]@{
                'local-gemma' = [ordered]@{
                    npm = '@ai-sdk/openai-compatible'
                    name = 'Gemma 4 vLLM'
                    options = [ordered]@{
                        baseURL = 'http://YOUR_VLLM_SERVER:8000/v1'
                    }
                    models = [ordered]@{
                        gemma4 = [ordered]@{
                            name = 'Gemma 4 31B'
                        }
                    }
                }
            }
            mcp = [ordered]@{
                g4 = [ordered]@{
                    type = 'remote'
                    url = 'http://localhost:9944/api/v4/g4/mcp'
                    enabled = $true
                }
                'g4-uia-recorder' = [ordered]@{
                    type = 'remote'
                    url = 'http://localhost:9955/api/v4/g4/recorders/uia/mcp'
                    enabled = $true
                }
            }
        }
        $config | ConvertTo-Json -Depth 8 | Set-Content -LiteralPath (Join-Path $partitionRoot 'opencode.json') -Encoding UTF8

        if ($isWindowsTarget) {
            $boxLauncher = @'
@echo off
setlocal
set "BOX_ROOT=%~dp0"
for %%D in (home data\roaming data\local temp config state cache config\opencode) do if not exist "%BOX_ROOT%%%D" mkdir "%BOX_ROOT%%%D"
set "HOME=%BOX_ROOT%home"
set "USERPROFILE=%BOX_ROOT%home"
set "APPDATA=%BOX_ROOT%data\roaming"
set "LOCALAPPDATA=%BOX_ROOT%data\local"
set "TEMP=%BOX_ROOT%temp"
set "TMP=%BOX_ROOT%temp"
set "XDG_CONFIG_HOME=%BOX_ROOT%config"
set "XDG_DATA_HOME=%BOX_ROOT%data"
set "XDG_STATE_HOME=%BOX_ROOT%state"
set "XDG_CACHE_HOME=%BOX_ROOT%cache"
set "PATH=%BOX_ROOT%runtime\bin;%PATH%"
set "OPENCODE_CONFIG=%BOX_ROOT%..\opencode.json"
set "OPENCODE_CONFIG_DIR=%BOX_ROOT%config\opencode"
set "OPENCODE_TUI_CONFIG=%BOX_ROOT%config\opencode\tui.json"
set "OPENCODE_DISABLE_AUTOUPDATE=1"
"%BOX_ROOT%runtime\bin\opencode.exe" %*
exit /b %ERRORLEVEL%
'@
            # Entry launcher: relaunch itself inside the bundled Windows Terminal, then start boxed OpenCode.
            # WT_SESSION is set by Windows Terminal in every shell it spawns, which guards against re-launch loops.
            $partitionLauncher = @'
@echo off
setlocal
set "PARTITION_ROOT=%~dp0"
set "WT_EXE=%PARTITION_ROOT%..\..\..\bot-utilities\windows-terminal\wt.exe"
if defined WT_SESSION goto run
if not exist "%WT_EXE%" goto run
start "" "%WT_EXE%" -w new --title "G4 OpenCode" -d "%PARTITION_ROOT%." cmd /k call "%PARTITION_ROOT%start-opencode.cmd" %*
exit /b 0
:run
cd /d "%PARTITION_ROOT%" || exit /b 1
if not exist "%PARTITION_ROOT%.opencode" mkdir "%PARTITION_ROOT%.opencode"
if not exist "%PARTITION_ROOT%.opencode\agents" mklink /J "%PARTITION_ROOT%.opencode\agents" "%PARTITION_ROOT%agents" >nul || exit /b 1
if not exist "%PARTITION_ROOT%.opencode\skills" mklink /J "%PARTITION_ROOT%.opencode\skills" "%PARTITION_ROOT%skills" >nul || exit /b 1
call "%PARTITION_ROOT%opencode\start.cmd" --auto %*
exit /b %ERRORLEVEL%
'@
            Set-Content -LiteralPath (Join-Path $boxRoot 'start.cmd') -Value $boxLauncher -Encoding ASCII
            Set-Content -LiteralPath (Join-Path $partitionRoot 'start-opencode.cmd') -Value $partitionLauncher -Encoding ASCII
        }
        else {
            $boxLauncher = @'
#!/usr/bin/env sh
set -eu
BOX_ROOT=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
mkdir -p "$BOX_ROOT/home" "$BOX_ROOT/data" "$BOX_ROOT/temp" "$BOX_ROOT/config/opencode" "$BOX_ROOT/state" "$BOX_ROOT/cache"
export HOME="$BOX_ROOT/home" XDG_CONFIG_HOME="$BOX_ROOT/config" XDG_DATA_HOME="$BOX_ROOT/data"
export XDG_STATE_HOME="$BOX_ROOT/state" XDG_CACHE_HOME="$BOX_ROOT/cache" TMPDIR="$BOX_ROOT/temp"
export PATH="$BOX_ROOT/runtime/bin:$PATH"
export OPENCODE_CONFIG="$BOX_ROOT/../opencode.json" OPENCODE_CONFIG_DIR="$BOX_ROOT/config/opencode"
export OPENCODE_TUI_CONFIG="$BOX_ROOT/config/opencode/tui.json" OPENCODE_DISABLE_AUTOUPDATE=1
exec "$BOX_ROOT/runtime/bin/opencode" "$@"
'@
            $partitionLauncher = @'
#!/usr/bin/env sh
set -eu
PARTITION_ROOT=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
cd "$PARTITION_ROOT"
mkdir -p "$PARTITION_ROOT/.opencode"
[ -e "$PARTITION_ROOT/.opencode/agents" ] || ln -s ../agents "$PARTITION_ROOT/.opencode/agents"
[ -e "$PARTITION_ROOT/.opencode/skills" ] || ln -s ../skills "$PARTITION_ROOT/.opencode/skills"
exec "$PARTITION_ROOT/opencode/start.sh" --auto "$@"
'@
            # ASCII keeps the shebang as byte zero under Windows PowerShell 5.1 (whose UTF8 adds a BOM).
            Set-Content -LiteralPath (Join-Path $boxRoot 'start.sh') -Value $boxLauncher -Encoding ASCII
            Set-Content -LiteralPath (Join-Path $partitionRoot 'start-opencode.sh') -Value $partitionLauncher -Encoding ASCII
        }
    }

    if ($isWindowsTarget) {
        $rootLauncher = @'
@echo off
setlocal
set "SANDBOX_ROOT=%~dp0"
set "PARTITION=g4-explorer"
if /i "%~1"=="g4-explorer" (
set "PARTITION=%~1"
shift
) else if /i "%~1"=="g4-orchestrator" (
set "PARTITION=%~1"
shift
)
call "%SANDBOX_ROOT%ai-agents\partitions\%PARTITION%\start-opencode.cmd" %*
exit /b %ERRORLEVEL%
'@
        Set-Content -LiteralPath (Join-Path $StageDirectory 'start-opencode.cmd') -Value $rootLauncher -Encoding ASCII
    }
    else {
        $rootLauncher = @'
#!/usr/bin/env sh
set -eu
SANDBOX_ROOT=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
PARTITION=g4-explorer
if [ "${1:-}" = g4-explorer ] || [ "${1:-}" = g4-orchestrator ]; then PARTITION=$1; shift; fi
exec "$SANDBOX_ROOT/ai-agents/partitions/$PARTITION/start-opencode.sh" "$@"
'@
        Set-Content -LiteralPath (Join-Path $StageDirectory 'start-opencode.sh') -Value $rootLauncher -Encoding ASCII
    }
}
finally {
    if (Test-Path -LiteralPath $extractionRoot) {
        Remove-Item -LiteralPath $extractionRoot -Recurse -Force
    }
}

