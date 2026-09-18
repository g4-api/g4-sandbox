# ---------------------------------------------------------------------------
# Script: G4 Sandbox Builder
#
# Purpose:
#   Builds a fully portable G4 sandbox environment by downloading,
#   assembling, and staging all required runtimes, browsers, drivers,
#   utilities, and configuration assets.
#
# Description:
#   - Orchestrates the end-to-end sandbox build process
#   - Delegates every deployment block to a standalone, self-contained
#     script under 'scripts-artifacts' (browsers/, runtimes/, ide/,
#     github/, ai-agents/)
#   - Each standalone script owns its own parameters and duplicates any
#     shared helper functions it needs; this script only calls them with
#     the relevant parameters
#   - Produces a deterministic, portable output layout suitable for:
#       * Local execution
#       * CI/CD artifacts
#       * Container mounting
#       * Air-gapped environments
#
# Compatibility:
#   - PowerShell 5.x (Windows)
#   - PowerShell Core (Windows, Linux, macOS)
#
# Assumptions:
#   - Network access to required upstream endpoints is available
#   - Output directory is writable
#   - tar is available on PATH for non-zip extractions when required
# ---------------------------------------------------------------------------
[CmdletBinding()]
param(
    # Root volume/path where the bot will operate.
    #
    # Notes:
    #   - Typically mounted into containers or used as the runtime working directory
    #   - Caller is responsible for ensuring sufficient disk space
    [string]$BotVolume,
    
    # Chrome version to download.
    #
    # Notes:
    #   - Passed through to Chrome artifact resolver
    #   - Can be full version (e.g., 120.0.6099.71) or major prefix (e.g., 120)
    #   - When omitted in downstream calls, latest stable may be used
    [Alias('ChormeVersion')]
    [string]$ChromeVersion,
    
    # .NET major version selector.
    #
    # Notes:
    #   - Default is "10"
    #   - Consumed by Get-Dotnet to resolve the correct runtime channel
    [string]$DotnetVersion = "10",

    # G4 Hub base URI.
    #
    # Notes:
    #   - Used by bots/services to communicate with the hub
    #   - Should be reachable from the runtime environment
    [string]$HubUri = "http://localhost:9944",
    
    # Target operating system.
    #
    # Notes:
    #   - Drives platform-specific artifact selection across the pipeline
    #   - Must match supported ValidateSet values
    [ValidateSet("Linux", "MacOs", "Windows")]
    [string]$OperatingSystem = "Windows",
    
    # Output directory for the assembled sandbox/package.
    #
    # Notes:
    #   - Relative paths are resolved from the current working directory
    #   - Will typically contain the final staged G4 bundle
    [string]$OutputDirectory = "/tmp/g4-sandbox",
    
    # When specified, performs a clean rebuild.
    #
    # Behavior:
    #   - Downstream steps may remove existing directories
    #   - Ensures deterministic build output
    [switch]$Clean,

    # When specified, skips the portable LiteLLM subsystem deployment.
    #
    # Notes:
    #   - The sandbox is published without the 'litellm' box
    #   - start-litellm.cmd / start-litellm.sh remain in the sandbox root but
    #     will report that the subsystem is missing
    [switch]$SkipLiteLLM
)

# Enable strict mode for safer scripting.
#
# Notes:
#   - Latest enforces:
#       * No use of uninitialized variables
#       * No referencing non-existent properties
#       * Stricter function semantics
Set-StrictMode -Version Latest

# Fail fast on all non-terminating errors.
#
# Notes:
#   - Converts many recoverable errors into terminating ones
#   - Ensures CI/CD pipelines fail deterministically
$ErrorActionPreference = 'Stop'

# ---------------------------------------------------------------------------
# Orchestration
#
# Every deployment block below delegates to a standalone, self-contained
# script under 'scripts-artifacts'. Each script owns its own parameters and
# duplicates any shared helper functions it needs; this script only calls
# them with the relevant parameters.
# ---------------------------------------------------------------------------

# Directory holding the extracted standalone deployment scripts.
$scriptsArtifactsDirectory = Join-Path $PSScriptRoot "scripts-artifacts"

# Resolve an optional GitHub token from the environment so the GitHub-facing
# scripts can access private repositories and raise the unauthenticated rate
# limit. The token is forwarded only when it is actually available.
$githubToken = [System.Environment]::GetEnvironmentVariable('GITHUB_TOKEN', 'Process')
if ([string]::IsNullOrWhiteSpace($githubToken)) {
    $githubToken = [System.Environment]::GetEnvironmentVariable('GH_TOKEN', 'Process')
}

# Splatting table used to forward the optional token to GitHub-facing scripts.
$tokenParameters = @{ }
if (-not [string]::IsNullOrWhiteSpace($githubToken)) {
    $tokenParameters['Token'] = $githubToken
}

$baseDirecotry = [System.IO.Path]::Combine($PSScriptRoot, "..", "..", "_g4")

# Base GitHub API URL for all g4-api repositories.
#
# Notes:
#   - TrimEnd ensures no double slash when appending repository names
$baseGithubUrl = "https://api.github.com/repos/g4-api".TrimEnd("/")

# Resolve the latest release tag for the g4-services repository.
#
# Notes:
#   - Returns values like: v1.2.3 or 1.2.3
#   - Used to version the sandbox output folder
#   - May return $null if the GitHub call fails
$sandboxVersion = & (Join-Path $scriptsArtifactsDirectory "github\Resolve-G4ArtifactLatestVersion.ps1") `
    -GitHubRepository "$($baseGithubUrl)/g4-services" `
    @tokenParameters

# Build the versioned sandbox output directory.
#
# Example result:
#   <OutputDirectory>\g4-sandbox-v1.2.3
#
# Notes:
#   - Embeds the resolved version into the folder name
#   - Caller should ensure $sandboxVersion is not null if strict behavior is required
$sandboxDirectory = Join-Path "$($OutputDirectory)" "g4-sandbox-$($sandboxVersion)"

# Source directory (current script location).
#
# Notes:
#   - Used for copying local assets (docker, k8s, cli, etc.)
$sourceDirectory = [System.IO.Path]::Combine($PSScriptRoot)

# Staging and working directories.
#
# Notes:
#   - "a" acts as the final assembled stage
#   - "_work" stores temporary archives during download/extraction
$stageDirectory = Join-Path $baseDirecotry "a"
$workDirectory  = Join-Path $baseDirecotry "_work"

# Structured stage subdirectories.
#
# Notes:
#   - Browsers: Chrome binaries
#   - Drivers: WebDriver binaries
#   - runtime: dotnet/jdk/nodejs
#   - utilities: supporting tools (VS Code, trackers, etc.)
$browsersDirectory  = Join-Path $stageDirectory "browsers"
$driversDirectory   = Join-Path $stageDirectory "drivers"
$runtimeDirectory   = Join-Path $stageDirectory "runtime"
$utilitiesDirectory = Join-Path $stageDirectory "bot-utilities"

# Resolve the Chromium recorder package from the same operating-system selection that drives Chrome and .NET.
# Windows retains compatibility with legacy generic x64 releases while preferring the explicit platform suffix.
$chromiumRecorderAssetPattern = switch ($OperatingSystem.ToLower()) {
    "windows" { "chromium-recorder\..*-(win-)?x64\.zip" }
    "linux"   { "chromium-recorder\..*-linux-x64\.tar\.gz" }
    default   { "chromium-recorder\..*-x64\.zip" }
}

# Tool definitions to download from GitHub releases.
#
# Notes:
#   - AssetPattern: Regex to match release asset
#   - DestinationDirectory: Where artifact will be extracted/copied
#   - DestinationFile: Optional rename of downloaded asset
#   - GitHubRepository: GitHub API endpoint for releases
#   - WindowsOnly: Skip tool when not running on Windows
$tools = @(
    @{
        AssetPattern         = $null
        DestinationDirectory = (Join-Path $utilitiesDirectory "ocr-inspector-win-x64")
        DestinationFile      = $null
        GitHubRepository     = "$($baseGithubUrl)/ocr-inspector"
        WindowsOnly          = $true
    },
    @{
        AssetPattern         = $null
        DestinationDirectory = (Join-Path $stageDirectory "g4-hub")
        DestinationFile      = $null
        GitHubRepository     = "$($baseGithubUrl)/g4-services"
        WindowsOnly          = $false
    },
    @{
        AssetPattern         = "selenium-server-.*\.jar"
        DestinationDirectory = (Join-Path $stageDirectory "selenium-grid")
        DestinationFile      = "selenium-server.jar"
        GitHubRepository     = "https://api.github.com/repos/SeleniumHQ/selenium"
        WindowsOnly          = $false
    },
    @{
        AssetPattern         = $null
        DestinationDirectory = (Join-Path $utilitiesDirectory "simple-encryptor-decryptor")
        DestinationFile      = $null
        GitHubRepository     = "$($baseGithubUrl)/simple-encryptor-decryptor"
        WindowsOnly          = $true
    },
    @{
        AssetPattern         = "Uia\.DriverServer.*-emgu\.zip"
        DestinationDirectory = [System.IO.Path]::Combine($driversDirectory, "uia-driver-server")
        DestinationFile      = $null
        GitHubRepository     = "$($baseGithubUrl)/uia-driver-server"
        WindowsOnly          = $true
    },
    @{
        AssetPattern         = "AccessibilityInsightsPortable.*\.zip"
        DestinationDirectory = (Join-Path $utilitiesDirectory "accessibility-insights-win-x64")
        DestinationFile      = $null
        GitHubRepository     = "$($baseGithubUrl)/uia-driver-server"
        WindowsOnly          = $true
    },
    @{
        AssetPattern         = "uia-recorder\..*-win-x64\.zip"
        DestinationDirectory = (Join-Path $utilitiesDirectory "uia-recorder-win-x64")
        DestinationFile      = $null
        GitHubRepository     = "$($baseGithubUrl)/g4-recorders"
        WindowsOnly          = $true
    },
    @{
        AssetPattern         = "uia-path-finder\..*-win-x64\.zip"
        DestinationDirectory = (Join-Path $utilitiesDirectory "uia-path-finder-win-x64")
        DestinationFile      = $null
        GitHubRepository     = "$($baseGithubUrl)/g4-recorders"
        WindowsOnly          = $true
    },
    @{
        AssetPattern         = $chromiumRecorderAssetPattern
        DestinationDirectory = (Join-Path $utilitiesDirectory "chromium-recorder-x64")
        DestinationFile      = $null
        GitHubRepository     = "$($baseGithubUrl)/g4-recorders"
        WindowsOnly          = $false
    }
)

# G4 Test Wright (portable test workbench). The release ships an OS-specific x64
# archive (win-x64.zip / linux-x64.tar.gz); macOS is not bundled here. The entry
# intentionally floats to the latest matching GitHub release asset and is added
# conditionally so a null pattern (e.g. MacOs) never falls through to the
# "first asset" selection in Get-G4Artifact.
$testWrightAssetPattern = switch ($OperatingSystem.ToLower()) {
    "windows" { "g4-test-wright-.*-win-x64\.zip" }
    "linux"   { "g4-test-wright-.*-linux-x64\.tar\.gz" }
    default   { $null }
}

if ($testWrightAssetPattern) {
    $tools += @{
        AssetPattern         = $testWrightAssetPattern
        DestinationDirectory = (Join-Path $utilitiesDirectory "g4-test-wright")
        DestinationFile      = $null
        GitHubRepository     = "$($baseGithubUrl)/g4-test-wright"
        WindowsOnly          = $false
    }
}

# Branch-archive sources to download from GitHub. This single mechanism serves
# both the source archive (g4-pytest-wrapper) and the repository working-tree
# snapshots for the published sandbox: each entry is downloaded as a GitHub
# branch source zip, extracted, and flattened into its destination directory.
#
# Notes:
#   - Repository: GitHub '<owner>/<repo>'
#   - Branch: branch head to archive (e.g. "main")
#   - DestinationDirectory: where the flattened source will land
#   - WindowsOnly: skip archive when not running on Windows
$archives = @(
    @{
        Repository           = "g4-api/g4-pytest-wrapper"
        Branch               = "main"
        DestinationDirectory = (Join-Path $utilitiesDirectory "g4-pytest-wrapper")
        WindowsOnly          = $false
    },
    @{
        Repository           = "g4-api/uia-driver-server"
        Branch               = "main"
        DestinationDirectory = ([System.IO.Path]::Combine($stageDirectory, "repos", "uia-driver-server"))
        WindowsOnly          = $false
    },
    @{
        Repository           = "g4-api/g4-vscode-extension"
        Branch               = "main"
        DestinationDirectory = ([System.IO.Path]::Combine($stageDirectory, "repos", "g4-vscode-extension"))
        WindowsOnly          = $false
    },
    @{
        Repository           = "g4-api/g4-recorders"
        Branch               = "main"
        DestinationDirectory = ([System.IO.Path]::Combine($stageDirectory, "repos", "g4-recorders"))
        WindowsOnly          = $false
    },
    @{
        Repository           = "g4-api/g4-services"
        Branch               = "main"
        DestinationDirectory = ([System.IO.Path]::Combine($stageDirectory, "repos", "g4-services"))
        WindowsOnly          = $false
    },
    @{
        Repository           = "g4-api/g4-plugins"
        Branch               = "main"
        DestinationDirectory = ([System.IO.Path]::Combine($stageDirectory, "repos", "g4-plugins"))
        WindowsOnly          = $false
    }
)

# VS Code extensions to pre-download as VSIX packages.
#
# Notes:
#   - These are stored offline under bot-utilities/vsixs
#   - Enables fully portable/offline dev environments
$vscodeExtensions = @(
    'echoapi.echoapi-for-vscode',
    "g4-api.g4-engine-client",
    "github.copilot-chat",
    "jakubkozera.csharp-dev-tools",
    "jakubkozera.ms-sql-manager",
    "ms-python.autopep8",
    "ms-python.black-formatter",
    "ms-python.debugpy",
    "ms-python.flake8",
    "ms-python.isort",
    "ms-python.pylint",
    "ms-python.python",
    "ms-python.vscode-pylance",
    "ms-python.vscode-python-envs",
    "ms-vscode.powershell",
    "ms-vscode-remote.remote-wsl",
    "sonarsource.sonarlint-vscode",
    "vscode-icons-team.vscode-icons"
)

# Node.js global dependencies to install into the bundled runtime.
#
# Notes:
#   - Installed globally into runtime/nodejs via the bundled npm
#   - Entries may be bare ("allure") or version-pinned ("allure@2.32.0")
$nodejsDependencies = @(
    "allure"
)

# Package OpenCode as a fully boxed runtime for both G4 agent partitions. Ripgrep is a required part of the
# unit: OpenCode's glob and grep tools both resolve rg from PATH and would otherwise download it on first use.
if ($OperatingSystem -eq 'MacOs') {
    throw [System.PlatformNotSupportedException]::new(
        'Portable OpenCode packaging currently supports Windows and Linux x64 targets only.')
}

& (Join-Path $scriptsArtifactsDirectory "ai-agents\Publish-PortableOpenCode.ps1") `
    -OperatingSystem $OperatingSystem `
    -ArchiveDirectory $workDirectory `
    -StageDirectory $stageDirectory

# Download Chrome + ChromeDriver.
#
# Notes:
#   - Artifacts are stored under browsers/<os>/chrome and drivers/<os>/chrome
#   - -Clean ensures deterministic rebuilds
& (Join-Path $scriptsArtifactsDirectory "browsers\Get-ChromeArtifacts.ps1") `
    -Version                    $ChromeVersion `
    -OperatingSystem            $OperatingSystem `
    -ArchiveDirectory           $workDirectory `
    -ChromeDestinationDirectory ([System.IO.Path]::Combine($browsersDirectory, "chrome")) `
    -DriverDestinationDirectory ([System.IO.Path]::Combine($driversDirectory, "chrome")) `
    -Clean

$chromeExecutableName = if ($OperatingSystem -eq "Windows") { "chrome.exe" } else { "chrome" }
$driverExecutableName = if ($OperatingSystem -eq "Windows") { "chromedriver.exe" } else { "chromedriver" }
$chromeExecutablePath = [System.IO.Path]::Combine($browsersDirectory, "chrome", $chromeExecutableName)
$driverExecutablePath = [System.IO.Path]::Combine($driversDirectory, "chrome", $driverExecutableName)

if (-not (Test-Path -LiteralPath $chromeExecutablePath -PathType Leaf)) {
    throw "Chrome deployment failed: '$($chromeExecutablePath)' was not created."
}

if (-not (Test-Path -LiteralPath $driverExecutablePath -PathType Leaf)) {
    throw "ChromeDriver deployment failed: '$($driverExecutablePath)' was not created."
}

# Download portable .NET runtime.
& (Join-Path $scriptsArtifactsDirectory "runtimes\Get-Dotnet.ps1") `
    -Version              $DotnetVersion `
    -OperatingSystem      $OperatingSystem `
    -ArchiveDirectory     $workDirectory `
    -DestinationDirectory (Join-Path $runtimeDirectory "dotnet") `
    -Clean

# Download OpenJDK binaries.
& (Join-Path $scriptsArtifactsDirectory "runtimes\Get-OpenJdkBinaries.ps1") `
    -OperatingSystem      $OperatingSystem `
    -ArchiveDirectory     $workDirectory `
    -DestinationDirectory (Join-Path $runtimeDirectory "jdk") `
    -Clean

# Download Node.js runtime.
& (Join-Path $scriptsArtifactsDirectory "runtimes\Get-NodeJs.ps1") `
    -OperatingSystem      $OperatingSystem `
    -ArchiveDirectory     $workDirectory `
    -DestinationDirectory (Join-Path $runtimeDirectory "nodejs") `
    -Clean

# Download VS Code portable build.
& (Join-Path $scriptsArtifactsDirectory "ide\Get-VSCode.ps1") `
    -OperatingSystem      $OperatingSystem `
    -ArchiveDirectory     $workDirectory `
    -DestinationDirectory (Join-Path $utilitiesDirectory "vs-code") `
    -Clean

# Download the portable Windows Terminal build (Windows target only).
#
# Notes:
#   - Windows Terminal is a Windows-only application; skipped for Linux/MacOs
#   - Staged in portable mode so the bundle stays self-contained
#   - Used by the generated start-opencode.cmd launchers to host the OpenCode TUI
if ($OperatingSystem -eq "Windows") {
    & (Join-Path $scriptsArtifactsDirectory "ide\Get-WindowsTerminal.ps1") `
        -ArchiveDirectory     $workDirectory `
        -DestinationDirectory (Join-Path $utilitiesDirectory "windows-terminal") `
        -Clean
}

# Download + extract Powershell Core.
& (Join-Path $scriptsArtifactsDirectory "runtimes\Get-PowershellCore.ps1") `
    -OperatingSystem      $OperatingSystem `
    -ArchiveDirectory     $workDirectory `
    -DestinationDirectory (Join-Path $utilitiesDirectory "powershell")

# Download the Python offline installer (Windows/macOS only).
& (Join-Path $scriptsArtifactsDirectory "runtimes\Get-Python.ps1") `
    -OperatingSystem      $OperatingSystem `
    -DestinationDirectory (Join-Path $utilitiesDirectory "python-installer") `
    -Clean

# GitHub Release Tools
#
# Notes:
#   - Delegated to scripts-artifacts/github/Get-G4Artifact.ps1, which accepts
#     the whole $tools array and loops internally; AssetPattern filters the
#     correct release asset and DestinationFile optionally renames it
& (Join-Path $scriptsArtifactsDirectory "github\Get-G4Artifact.ps1") `
    -Tools                $tools `
    -ArchiveDirectory     $workDirectory `
    -OperatingSystem      $OperatingSystem `
    @tokenParameters

# GitHub Branch Archives and Repository Snapshots
#
# Notes:
#   - Both the plain source archives and the repository working-tree snapshots
#     are downloaded as GitHub branch source zips by
#     scripts-artifacts/github/Get-GitHubBranchArchive.ps1, which accepts the
#     whole $archives array and loops internally
& (Join-Path $scriptsArtifactsDirectory "github\Get-GitHubBranchArchive.ps1") `
    -Archives             $archives `
    -ArchiveDirectory     $workDirectory `
    -OperatingSystem      $OperatingSystem `
    @tokenParameters

# VSIX Extensions (Offline Packaging)
#
# Notes:
#   - Delegated to scripts-artifacts/ide/Get-VSCodeVsix.ps1, which accepts the
#     whole $vscodeExtensions array, loops internally, and retries each
#     extension download up to 3 times (non-fatal on final failure)
& (Join-Path $scriptsArtifactsDirectory "ide\Get-VSCodeVsix.ps1") `
    -Plugins              $vscodeExtensions `
    -DestinationDirectory (Join-Path $utilitiesDirectory "vsixs")

# Select OS-specific startup scripts folder.
#   - Windows      -> scripts-windows (.cmd)
#   - Linux/MacOs  -> scripts-linux  (.sh)
$scriptsFolderName = if ($OperatingSystem -eq "Windows") { "scripts-windows" } else { "scripts-linux" }

# Define all sandbox copy operations in a single collection.
#
# Each entry contains:
#   Path        -> Source path (supports wildcards when copying contents)
#   Destination -> Target directory that will be ensured before copy
#
# Notes:
# - Wildcard (*) means "copy contents of folder"
# - No wildcard means "copy the folder itself"
# - Using a table-driven approach keeps the logic clean and scalable
$sandboxSources = @(
    @{
        # Copy OS-specific startup scripts into the stage root so they land
        # directly in the sandbox root (beside g4-hub/, runtime/, etc.)
        Path        = (Join-Path $sourceDirectory "$scriptsFolderName\*")
        Destination = $stageDirectory
    },
    @{
        # Copy g4-cli contents into bot-root
        Path        = (Join-Path $sourceDirectory "g4-cli\*")
        Destination = (Join-Path $stageDirectory "bot-root")
    },
    @{
        # Copy selenium grid configuration files
        Path        = (Join-Path $sourceDirectory "selenium-grid\*")
        Destination = ([System.IO.Path]::Combine($stageDirectory, "selenium-grid", "configurations"))
    },
    @{
        # Copy the entire docker folder (no wildcard = include folder root)
        Path        = (Join-Path $sourceDirectory "docker")
        Destination = $stageDirectory
    },
    @{
        # Copy docker-compose files
        Path        = (Join-Path $sourceDirectory "docker-compose\*")
        Destination = (Join-Path $stageDirectory "docker-compose")
    },
    @{
        # Copy the entire k8s folder
        Path        = (Join-Path $sourceDirectory "k8s")
        Destination = $stageDirectory
    },
    @{
        # Copy utilities scripts into utilities/scripts
        Path        = (Join-Path $sourceDirectory "utilities\*")
        Destination = (Join-Path $utilitiesDirectory "scripts")
    }
)

# Iterate through each copy definition and execute safely
foreach ($sandboxSource in $sandboxSources) {

    # ---------------------------------------------------------------------
    # Ensure destination directory exists BEFORE copy.
    # This prevents the classic PowerShell issue where:
    #   - Single file copy -> destination treated as file
    #   - Multiple files   -> destination treated as directory
    #
    # -Force makes this idempotent and CI-safe.
    # ---------------------------------------------------------------------
    New-Item `
        -ItemType Directory `
        -Path     $sandboxSource.Destination `
        -Force `
    | Out-Null

    # ---------------------------------------------------------------------
    # Perform recursive copy.
    #
    # Behavior:
    # -Recurse -> include subfolders
    # -Force   -> overwrite existing files and bypass read-only
    #
    # Because we pre-created the directory, this is now deterministic
    # for 0 / 1 / many files.
    # ---------------------------------------------------------------------
    Copy-Item `
        -Path        $sandboxSource.Path `
        -Destination $sandboxSource.Destination `
        -Recurse `
        -Force
}

# Install Node.js global dependencies into the bundled runtime.
#
# Notes:
#   - This is the last staging step before files are copied into the sandbox,
#     so the installed modules are included in the final bundle.
#   - Uses the bundled (staged) npm only. If the staged node/npm cannot be
#     located (e.g. building a Linux bundle on a Windows host), the phase is
#     skipped with a warning rather than aborting the build.
#   - Packages are installed globally with --prefix pointing at runtime/nodejs
#     (Windows' default global prefix is %APPDATA%\npm, not the node dir).
if ($nodejsDependencies -and $nodejsDependencies.Count -gt 0) {

    $nodejsRuntimeDirectory = Join-Path $runtimeDirectory "nodejs"

    # Resolve the staged node binary and npm CLI entry point per target OS.
    if ($OperatingSystem -eq "Windows") {
        $nodeExecutable = Join-Path $nodejsRuntimeDirectory "node.exe"
        $npmCli = [System.IO.Path]::Combine($nodejsRuntimeDirectory, "node_modules", "npm", "bin", "npm-cli.js")
    }
    else {
        $nodeExecutable = [System.IO.Path]::Combine($nodejsRuntimeDirectory, "bin", "node")
        $npmCli = [System.IO.Path]::Combine($nodejsRuntimeDirectory, "lib", "node_modules", "npm", "bin", "npm-cli.js")
    }

    if (-not (Test-Path -Path $nodeExecutable) -or -not (Test-Path -Path $npmCli)) {
        Write-Warning "Bundled Node.js runtime not found (node: '$($nodeExecutable)', npm: '$($npmCli)'). Skipping Node.js dependency installation."
    }
    else {
        foreach ($dependency in $nodejsDependencies) {

            Write-Host "Installing Node.js dependency (global): '$($dependency)'" -ForegroundColor DarkGray

            # Invoke the bundled node against npm-cli.js to avoid relying on
            # shell shims or PATH. --prefix forces the install into the bundle.
            & $nodeExecutable $npmCli install --global $dependency --prefix $nodejsRuntimeDirectory

            if ($LASTEXITCODE -ne 0) {
                Write-Warning "Failed to install Node.js dependency: '$($dependency)' (exit code: $($LASTEXITCODE))."
            }
            else {
                Write-Host "Installed Node.js dependency: '$($dependency)'" -ForegroundColor Cyan
            }
        }
    }
}

# Deploy the portable LiteLLM subsystem into the stage.
#
# Notes:
#   - Runs after every download and after the sandbox file copies, so the box
#     is the last thing added before the stage is copied into the sandbox.
#   - Windows and Linux targets each get their own deployment script in
#     'scripts-subsystems'; any other platform is skipped as unsupported.
#   - Failures are non-fatal and only warn.
if ($SkipLiteLLM) {
    Write-Host "Skipping the LiteLLM subsystem deployment (-SkipLiteLLM)." -ForegroundColor DarkGray
}
else {
    $deployScriptName = switch ($OperatingSystem.ToLowerInvariant()) {
        'windows' { 'deploy-litellm-win.ps1' }
        'linux'   { 'deploy-litellm-linux.ps1' }
        default   { $null }
    }

    # Unsupported platforms (for example MacOs) are skipped, not failed.
    if ([string]::IsNullOrWhiteSpace($deployScriptName)) {
        Write-Warning "LiteLLM subsystem: unsupported operating system '$($OperatingSystem)'. Skipping deployment."
    }
    else {
        $deployScriptPath = Join-Path (Join-Path $sourceDirectory "scripts-subsystems") $deployScriptName

        # The deployment scripts are part of the repository; a missing file is a
        # packaging problem, but must not abort an otherwise valid publish.
        if (-not (Test-Path -LiteralPath $deployScriptPath)) {
            Write-Warning "LiteLLM subsystem: deployment script '$($deployScriptPath)' was not found. Skipping deployment."
        }
        else {
            # The LiteLLM box lives in the sandbox root so the generated
            # start-litellm.cmd / start-litellm.sh sit beside the root launchers.
            $containerRoot = Join-Path $stageDirectory 'litellm'
            New-Item -ItemType Directory -Path $containerRoot -Force | Out-Null

            Write-Host "Deploying the portable LiteLLM subsystem into '$($containerRoot)'..." -ForegroundColor DarkGray

            # The deployment scripts are standalone programs with their own error
            # handling and are not written against StrictMode 'Latest'. Relax both
            # settings for the duration of the call, then restore them so the
            # remainder of this script keeps its strict behavior.
            $previousErrorActionPreference = $ErrorActionPreference
            try {
                Set-StrictMode -Off
                $ErrorActionPreference = 'Continue'

                # Build the box (downloads uv, CPython, LiteLLM, Prisma and
                # PostgreSQL, initializes the database and verifies the runtime).
                & $deployScriptPath -Action Deploy -ContainerRoot $containerRoot

                if ($null -ne $LASTEXITCODE -and $LASTEXITCODE -ne 0) {
                    throw [System.InvalidOperationException]::new(
                        "'$($deployScriptName)' exited with code $($LASTEXITCODE).")
                }

                # Stop the detached PostgreSQL server so the staged box can be
                # safely copied to the final sandbox location.
                & $deployScriptPath -Action Stop -ContainerRoot $containerRoot

                Write-Host "LiteLLM subsystem deployed successfully." -ForegroundColor Green
            }
            catch {
                Write-Warning "LiteLLM subsystem deployment failed: $($_.Exception.Message). Continuing without LiteLLM."
            }
            finally {
                Set-StrictMode -Version Latest
                $ErrorActionPreference = $previousErrorActionPreference
            }
        }
    }
}

# Remove existing sandbox directory if requested.
#
# Notes:
#   - SilentlyContinue avoids noise if the directory does not exist.
#   - LiteralPath avoids wildcard interpretation.
if ($Clean) {
    $ProgressPreference = 'SilentlyContinue'
    Remove-Item `
        -LiteralPath $sandboxDirectory `
        -Recurse `
        -Force `
        -ErrorAction SilentlyContinue
    $ProgressPreference = 'Continue'
}

# Ensure the sandbox root directory exists.
New-Item -ItemType Directory -Path $sandboxDirectory -Force | Out-Null

# Resolve and normalize the stage root ONCE (important for performance).
#
# Notes:
#   - TrimEnd ensures consistent substring math later.
$stageRoot = (Resolve-Path $stageDirectory).Path.TrimEnd('\', '/')

# Copy directories before files so required empty runtime directories, such as
# PostgreSQL's pg_notify, survive publication.
$directories = Get-ChildItem -Path $stageDirectory -Recurse -Force -Directory

foreach ($directory in $directories) {
    $fullPath = (Resolve-Path $directory.FullName).Path

    if (-not $fullPath.StartsWith($stageRoot, [System.StringComparison]::OrdinalIgnoreCase)) {
        Write-Warning "Directory path is not under stage directory: $($fullPath)"
        continue
    }

    $relativePath = $fullPath.Substring($stageRoot.Length).TrimStart('\', '/')
    $destinationPath = Join-Path $sandboxDirectory $relativePath
    New-Item -ItemType Directory -Path $destinationPath -Force | Out-Null
}

# Get all FILES to copy (not directories), so progress can reach 100%.
#
# Notes:
#   - Using "*" ensures contents of the directory, not the directory itself.
#   - -File ensures we count/copy only files (no folders).
#   - -Force includes hidden/system files.
$items = Get-ChildItem -Path $stageDirectory -Recurse -Force -File
$total = $items.Count
$index = 0
$lastIndex = -1

foreach ($item in $items) {

    # Resolve full normalized path of the current file.
    # (Resolve-Path can be slower; keep it if you want canonical paths.)
    $fullPath = (Resolve-Path $item.FullName).Path

    # Safety check: ensure we only copy from inside stageRoot.
    if (-not $fullPath.StartsWith($stageRoot, [System.StringComparison]::OrdinalIgnoreCase)) {
        Write-Warning "Item path is not under stage directory: $($fullPath)"
        continue
    }

    # Build destination path while preserving the stageRoot-relative structure.
    $relativePath = $fullPath.Substring($stageRoot.Length).TrimStart('\', '/')
    $destinationPath = Join-Path $sandboxDirectory $relativePath

    # Ensure destination directory exists.
    $destDir = Split-Path $destinationPath -Parent
    if (-not (Test-Path $destDir)) {
        New-Item -ItemType Directory -Path $destDir -Force | Out-Null
    }

    # Copy the file, then increment progress counter.
    Copy-Item -Path $item.FullName -Destination $destinationPath -Force
    $index++

    # Compute percent based on FILES completed.
    $percent = if ($total -gt 0) { [int](($index / $total) * 100) } else { 100 }

    # Update progress only when counter changes (cheap throttle).
    if ($index -ne $lastIndex) {
        Write-Progress `
            -Activity        "Copying files to sandbox" `
            -Status          "$($percent)% complete ($index/$total)" `
            -PercentComplete $percent
        $lastIndex = $index
    }
}

# Force a final 100% update so the UI always completes cleanly.
Write-Progress `
    -Activity        "Copying files to sandbox" `
    -Status          "100% complete ($total/$total)" `
    -PercentComplete 100 `
    -Completed

# A staged PostgreSQL cluster is valid only if its required empty directories
# also reached the published sandbox.
$stagedPostgresData = [System.IO.Path]::Combine($stageDirectory, "litellm", "data", "postgresql")
$publishedPostgresData = [System.IO.Path]::Combine($sandboxDirectory, "litellm", "data", "postgresql")

if (Test-Path -LiteralPath (Join-Path $stagedPostgresData "PG_VERSION")) {
    $requiredPostgresDirectories = @(
        "pg_commit_ts",
        "pg_dynshmem",
        "pg_notify",
        "pg_replslot",
        "pg_serial",
        "pg_snapshots",
        "pg_stat_tmp",
        "pg_tblspc",
        "pg_twophase"
    )

    $missingPostgresDirectories = @(
        $requiredPostgresDirectories |
            Where-Object { -not (Test-Path -LiteralPath (Join-Path $publishedPostgresData $_) -PathType Container) }
    )

    if ($missingPostgresDirectories.Count -gt 0) {
        throw "Published PostgreSQL cluster is incomplete. Missing directories: $($missingPostgresDirectories -join ', ')."
    }
}

$publishedRuntimeStatePath = [System.IO.Path]::Combine(
    $sandboxDirectory,
    "litellm",
    "state",
    "active-runtime.json")
if (Test-Path -LiteralPath $publishedRuntimeStatePath) {
    try {
        $publishedRuntimeState = Get-Content -LiteralPath $publishedRuntimeStatePath -Raw | ConvertFrom-Json
    }
    catch {
        throw "Published LiteLLM runtime state is invalid: $($_.Exception.Message)"
    }

    if ([string]::IsNullOrWhiteSpace([string]$publishedRuntimeState.active)) {
        throw "Published LiteLLM runtime state does not identify an active runtime."
    }

    $queryEngineName = if ($OperatingSystem -eq "Windows") { "query-engine.exe" } else { "query-engine" }
    $publishedQueryEnginePath = [System.IO.Path]::Combine(
        $sandboxDirectory,
        "litellm",
        "runtimes",
        [string]$publishedRuntimeState.active,
        "prisma",
        $queryEngineName)

    if (-not (Test-Path -LiteralPath $publishedQueryEnginePath -PathType Leaf)) {
        throw "Published LiteLLM Prisma query engine is missing: $publishedQueryEnginePath"
    }
}

# Ensure startup scripts are executable on Unix-like targets.
#
# Notes:
#   - Only relevant for Linux/MacOs bundles (.sh scripts in the sandbox root)
#   - Guarded so building a Linux sandbox on a Windows host does not hard-fail
if ($OperatingSystem -ne "Windows") {
    $chmod = Get-Command chmod -ErrorAction SilentlyContinue
    if ($chmod) {
        Get-ChildItem -Path $sandboxDirectory -Filter "*.sh" -Recurse -File | ForEach-Object {
            Write-Host "Setting execute permissions on script: '$($_.FullName)'" -ForegroundColor DarkGray
            chmod +x $_.FullName
        }

        Get-ChildItem -Path (Join-Path $sandboxDirectory "ai-agents/partitions") -Recurse -File |
            Where-Object { $_.Name -eq "opencode" -or $_.Name -eq "rg" } |
            ForEach-Object { chmod +x $_.FullName }
    }
    else {
        Write-Warning "chmod not found on PATH; skipping execute-permission step for .sh scripts."
    }
}

# Remove directory recursively.
#
# Notes:
#   - Suppresses noisy internal progress ("Removing X items") in PS7+.
#   - Uses -LiteralPath to avoid wildcard interpretation.
#   - -ErrorAction Stop ensures failures are caught by try/catch.
$ProgressPreference = 'SilentlyContinue'

try {
    Write-Host "Removing sandbox directory..." -ForegroundColor DarkGray
    Write-Host "Target: $baseDirecotry" -ForegroundColor DarkGray

    Remove-Item `
        -LiteralPath $baseDirecotry `
        -Recurse `
        -Force `
        -ErrorAction Stop

    # Success message
    Write-Host "Directory removed successfully." -ForegroundColor DarkGray
}
catch {
    # Provide meaningful warning with context.
    Write-Warning "Failed to remove directory: $($baseDirecotry)"
    Write-Warning "Reason: $($_.Exception.Message)"
}
finally {
    # Always restore progress behavior to avoid global side effects.
    $ProgressPreference = 'Continue'
}

# Create or overwrite .env
$envFile = @"
G4_HUB_URI=$($HubUri)
G4_LICENSE_TOKEN=
G4_REGISTRATION_TIMEOUT=60
G4_WATCHDOG_INTERVAL=60

BOT_NAME
BOT_VOLUME=$($BotVolume)

DRIVER_BINARIES=
"@

$envFile | Set-Content -Path (Join-Path $sandboxDirectory ".env") -Encoding UTF8

# Mark progress as completed.
Write-Progress -Activity "Copying files to sandbox" -Completed

Write-Host ""
Write-Host "============================================================" -ForegroundColor DarkGray
Write-Host "   G4 Sandbox creation completed successfully"                -ForegroundColor Green
Write-Host "   Location: $($sandboxDirectory)"                            -ForegroundColor Cyan
Write-Host "============================================================" -ForegroundColor DarkGray
Write-Host ""