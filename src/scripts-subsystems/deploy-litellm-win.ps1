<#
.SYNOPSIS
    Deploys, updates, and manages a fully portable, self-contained LiteLLM proxy stack on Windows.

.DESCRIPTION
    deploy-litellm-win.ps1 replaces the previous collection of Windows batch scripts with a
    single Windows PowerShell 5.1 entry point. See deploy-litellm-linux.ps1 for the Linux
    (PowerShell 7) equivalent.

    Every runtime is downloaded into this script's own directory ("the box") and nothing is
    installed globally: uv, a uv-managed CPython, LiteLLM and its Python dependencies, the
    Prisma Node toolchain, and PostgreSQL. No machine-level, user-level, registry, or profile
    state is modified; all redirection happens through process-local environment variables.

    Box layout
    ----------
      box\
        uv.exe                       shared uv binary
        postgresql\                  shared PostgreSQL binaries      -.
        data\postgresql\             the database cluster            | never rebuilt by an update
        state\config.yaml            your model_list (user-owned)    |
        state\active-runtime.json    { active, previous, history }   |
        state\deploy-complete.json                                  -'
        cache\uv\                    shared uv cache
        bin\                         generated helper files (version-agnostic)
        home\  temp\
        runtimes\
          litellm-1.98.0\            slug = litellm-<version>
            python\ packages\ prisma\  manifest.json
        start-litellm.cmd

    prisma (Python) is not hard-coded: the exact version is read from LiteLLM's own uv.lock at
    tag v<LiteLLMVersion> - the version LiteLLM's Docker image and CI test with - because
    LiteLLM only declares a range in pyproject.toml and keeps prisma in its "extra-proxy" extra
    (so litellm[proxy] does not pull it, and resolving the range gets the newest rather than the
    tested one). Its internal Prisma CLI + engine defaults are then left in force (PRISMA_VERSION
    unset), and the nodeenv Node.js version defaults to 20. Pass -PrismaPythonVersion /
    -PrismaCliVersion / -PrismaEngineVersion / -PrismaNodeVersion to override;
    -PrismaPythonFallbackVersion covers an offline uv.lock lookup.

    Actions
    -------
      Deploy    Build the box and the runtime for -LiteLLMVersion, initialize PostgreSQL and the
                LiteLLM database, verify, and record the runtime as active. -Force wipes the box
                (including the database) first. -Start launches the proxy afterwards.
      Update    Build a NEW runtime for -LiteLLMVersion beside the current one, run database
                migrations against the existing cluster, verify, then switch the active runtime.
                The previous runtime is kept for rollback. Config and data are untouched.
      Rollback  Switch the active runtime back to the previous one. No rebuild. The database
                schema is not reverted (Prisma migrations are forward-only).
      Start     Ensure PostgreSQL is running, then launch the active runtime's proxy foreground.
      Stop      Stop the portable PostgreSQL server.
      Verify    Re-run verification for the active runtime.
      Status    Report installed runtimes, the active one, and service reachability.

.PARAMETER Action
    Deploy, Update, Rollback, Start, Stop, Verify, or Status. Defaults to Deploy.

.PARAMETER Force
    Deploy: wipe the box (runtimes, data, cache, state, bin, postgresql, home, temp) before
    rebuilding - destroys the database. Update: rebuild the target runtime even if it is
    already the active one.

.PARAMETER Start
    Deploy only. Launch the LiteLLM proxy in the foreground after a successful deployment.

.PARAMETER ContainerRoot
    The box directory. Defaults to the directory that contains this script.

.PARAMETER UvVersion
    Version of uv to download.

.PARAMETER UvHttpTimeout
    Per-request HTTP read timeout (seconds) for uv package downloads. Default 180 (uv's own
    default is 30, which is too short on a slow link).

.PARAMETER UvHttpRetries
    Retry count for failed uv HTTP requests. Default 8.

.PARAMETER UvConcurrentDownloads
    Maximum parallel uv downloads. Default 8 (uv's own default is ~50; fewer connections give
    each download more of a thin pipe).

.PARAMETER PythonVersion
    Full uv-managed CPython version to install per runtime (for example 3.13.15).

.PARAMETER LiteLLMVersion
    LiteLLM version to install as litellm[proxy]. Also names the runtime slug.

.PARAMETER PrismaPythonVersion
    Optional. Pin the prisma (Python client) version explicitly. Empty (default): the exact
    version is read from LiteLLM's own uv.lock at tag v<LiteLLMVersion>.

.PARAMETER PrismaPythonFallbackVersion
    prisma (Python client) version used only when the uv.lock lookup fails (offline, tag or
    file missing, unparseable). Default 0.11.0. A loud warning is printed when it is used.

.PARAMETER PrismaCliVersion
    Optional. Pin the Prisma CLI (npm) version via PRISMA_VERSION. Empty: left unset, so
    prisma-client-python uses its own internal default (the correct value by construction).

.PARAMETER PrismaEngineVersion
    Optional. Pin the Prisma engine commit hash via PRISMA_EXPECTED_ENGINE_VERSION. Empty:
    left unset.

.PARAMETER PrismaNodeVersion
    Optional. Override the Node.js version the Prisma nodeenv installs. Empty: Node 20, unless
    -PrismaCliVersion is set to a 6.x+ value (then Node 22).

.PARAMETER PyWin32Version
    pywin32 version to install. Required for the LiteLLM MCP routes on Windows.

.PARAMETER PostgresVersion
    EnterpriseDB PostgreSQL Windows binary version tag (for example 17.11-1).

.PARAMETER PostgresHostAddress
    Loopback address PostgreSQL listens on and clients connect to.

.PARAMETER PostgresPort
    TCP port for the portable PostgreSQL server.

.PARAMETER PostgresDatabase
    LiteLLM database name.

.PARAMETER PostgresUser
    LiteLLM database role name.

.PARAMETER PostgresPassword
    LiteLLM database role password. Local-only development default; override for non-local use.
    URL-encoded into DATABASE_URL and SQL-escaped into the role creation script.

.PARAMETER LiteLLMHostAddress
    Address the LiteLLM proxy binds to.

.PARAMETER LiteLLMPort
    TCP port the LiteLLM proxy binds to.

.PARAMETER LiteLLMMasterKey
    LiteLLM master key. Passed through the LITELLM_MASTER_KEY environment variable, not written
    into config.yaml, so it takes effect without editing the user-owned config.

.PARAMETER StoreModelInDb
    When $true (default) sets STORE_MODEL_IN_DB=True so models can be added and edited from the
    admin UI (persisted to PostgreSQL). Pass -StoreModelInDb $false to disable.

.PARAMETER UpstreamModel
    Model name written into a freshly created config.yaml.

.PARAMETER UpstreamApiBase
    Base URL of the upstream OpenAI-compatible endpoint written into a freshly created
    config.yaml.

.PARAMETER UvDownloadUrl
    Override for the uv release archive URL. Derived from UvVersion when omitted.

.PARAMETER PostgresDownloadUrl
    Override for the PostgreSQL binary archive URL. Derived from PostgresVersion when omitted.

.PARAMETER LiteLLMArgument
    Remaining arguments passed verbatim to the LiteLLM proxy for Start and Deploy -Start.

.EXAMPLE
    .\deploy-litellm-win.ps1
    Deploy the default LiteLLM version into the current box directory.

.EXAMPLE
    .\deploy-litellm-win.ps1 -Action Update -LiteLLMVersion 1.99.0
    Build a runtime for 1.99.0, migrate the database, and switch to it. 1.98.0 is kept.

.EXAMPLE
    .\deploy-litellm-win.ps1 -Action Rollback
    Switch back to the previously active runtime.

.EXAMPLE
    .\deploy-litellm-win.ps1 -Action Status
    List installed runtimes, the active one, and service reachability.

.INPUTS
    None.

.OUTPUTS
    System.Management.Automation.PSCustomObject

.NOTES
    Target host      : Windows PowerShell 5.1 on Windows 11 (x64; ARM64 via x64 emulation).
    Isolation        : No global install of Python, Node, Prisma, PostgreSQL, or uv. Windows
                       PowerShell is used only as the bootstrap and downloader.
    Redis            : Omitted. LITELLM_DISABLE_NO_REDIS_WARNING=true (single-worker profile).
    Prisma watchdog  : PRISMA_HEALTH_WATCHDOG_ENABLED=false. The LiteLLM watchdog falls back to
                       os.kill(pid, 0) on Windows, which can terminate the Prisma query engine.
    MCP support      : pywin32 is installed into the runtime's packages directory and
                       litellm-portable.py processes the .pth files there so pywintypes loads
                       and the /v1/mcp/... routes register.
    Not deployed     : vLLM. The default config expects http://127.0.0.1:8000/v1 serving
                       Qwen/Qwen3-0.6B.
#>
#Requires -Version 5.1

[CmdletBinding(SupportsShouldProcess = $true, PositionalBinding = $false)]
param(
    [Parameter()]
    [ValidateSet('Deploy', 'Update', 'Rollback', 'Start', 'Stop', 'Verify', 'Status')]
    [string]$Action = 'Deploy',

    [Parameter()]
    [switch]$Force,

    [Parameter()]
    [switch]$Start,

    [Parameter()]
    [string]$ContainerRoot,

    [Parameter()]
    [ValidateNotNullOrEmpty()]
    [string]$UvVersion = '0.12.6',

    [Parameter()]
    [ValidateRange(10, 3600)]
    [int]$UvHttpTimeout = 180,

    [Parameter()]
    [ValidateRange(0, 50)]
    [int]$UvHttpRetries = 8,

    [Parameter()]
    [ValidateRange(1, 64)]
    [int]$UvConcurrentDownloads = 8,

    [Parameter()]
    [ValidateNotNullOrEmpty()]
    [string]$PythonVersion = '3.13.15',

    [Parameter()]
    [ValidateNotNullOrEmpty()]
    [string]$LiteLLMVersion = '1.98.0',

    [Parameter()]
    [string]$PrismaPythonVersion = '',

    [Parameter()]
    [ValidateNotNullOrEmpty()]
    [string]$PrismaPythonFallbackVersion = '0.11.0',

    [Parameter()]
    [string]$PrismaCliVersion = '',

    [Parameter()]
    [string]$PrismaEngineVersion = '',

    [Parameter()]
    [string]$PrismaNodeVersion = '',

    [Parameter()]
    [ValidateNotNullOrEmpty()]
    [string]$PyWin32Version = '312',

    [Parameter()]
    [ValidateNotNullOrEmpty()]
    [string]$PostgresVersion = '17.11-1',

    [Parameter()]
    [ValidateNotNullOrEmpty()]
    [string]$PostgresHostAddress = '127.0.0.1',

    [Parameter()]
    [ValidateRange(1, 65535)]
    [int]$PostgresPort = 54321,

    [Parameter()]
    [ValidateNotNullOrEmpty()]
    [string]$PostgresDatabase = 'litellm',

    [Parameter()]
    [ValidateNotNullOrEmpty()]
    [string]$PostgresUser = 'litellm',

    [Parameter()]
    [ValidateNotNullOrEmpty()]
    [string]$PostgresPassword = 'litellm-local',

    [Parameter()]
    [ValidateNotNullOrEmpty()]
    [string]$LiteLLMHostAddress = '127.0.0.1',

    [Parameter()]
    [ValidateRange(1, 65535)]
    [int]$LiteLLMPort = 4000,

    [Parameter()]
    [ValidateNotNullOrEmpty()]
    [string]$LiteLLMMasterKey = 'sk-1234',

    [Parameter()]
    [bool]$StoreModelInDb = $true,

    [Parameter()]
    [ValidateNotNullOrEmpty()]
    [string]$UpstreamModel = 'Qwen/Qwen3-0.6B',

    [Parameter()]
    [ValidateNotNullOrEmpty()]
    [string]$UpstreamApiBase = 'http://127.0.0.1:8000/v1',

    [Parameter()]
    [string]$UvDownloadUrl,

    [Parameter()]
    [string]$PostgresDownloadUrl,

    [Parameter(ValueFromRemainingArguments = $true)]
    [string[]]$LiteLLMArgument
)

Set-StrictMode -Version 3.0
$ErrorActionPreference = 'Stop'

# Harmless on Windows PowerShell 5.1 (the automatic variable does not exist there); on
# PowerShell 7.4+ it keeps a non-zero native exit from becoming a terminating error, which the
# explicit exit-code checks in this script rely on.
$PSNativeCommandUseErrorActionPreference = $false

# ---------------------------------------------------------------------------
# Constants
# ---------------------------------------------------------------------------

# Directories removed by Deploy -Force. The box is rebuilt from zero afterwards.
$script:CleanupDirectoryNames = @('runtimes', 'data', 'cache', 'state', 'bin', 'postgresql', 'home', 'temp')

# Shared directories created on every Deploy.
$script:SharedLayoutDirectories = @(
    'data', 'data\roaming', 'data\local', 'state', 'cache', 'cache\uv', 'cache\litellm-locks',
    'bin', 'home', 'temp', 'runtimes'
)

# Directories created inside a runtime slug directory. prisma\nodeenv is owned by the pre-seed.
$script:RuntimeLayoutDirectories = @('python', 'packages', 'prisma', 'prisma\binaries', 'prisma\npm')

$script:ActiveRuntimeStateRelativePath = 'state\active-runtime.json'
$script:DeployCompleteMarkerRelativePath = 'state\deploy-complete.json'
$script:ConfigRelativePath = 'state\config.yaml'

# Node.js version the Prisma nodeenv installs, selected by the resolved Prisma CLI major.
$script:NodeVersionForModernPrisma = '22.23.2'
$script:NodeVersionForLegacyPrisma = '20.20.2'

# Runtime slug directories to keep after an update (active + previous are always kept on top).
$script:RuntimeHistoryLimit = 5

# LiteLLM's uv lockfile - the source of the exact tested prisma version. {0} is the git ref.
$script:LiteLLMLockUrlTemplates = @(
    'https://raw.githubusercontent.com/BerriAI/litellm/{0}/uv.lock',
    'https://raw.githubusercontent.com/BerriAI/litellm/{0}/poetry.lock'
)
$script:LiteLLMLockCacheRelativeDir = 'cache\litellm-locks'

# Probes that the generated Prisma client is usable (catches a client / runtime version skew
# before it surfaces as a warning at proxy start). Success is exit code 0 - no output line,
# because Windows PowerShell 5.1 mangles embedded double quotes in a native -c argument.
$script:PrismaClientConstructExpression = "import prisma; prisma.Prisma()"

$script:PrismaClientConnectExpression = @'
import asyncio, prisma
_loop = asyncio.new_event_loop()
_db = prisma.Prisma()
_loop.run_until_complete(_db.connect())
_loop.run_until_complete(_db.disconnect())
_loop.close()
'@

# Runs through litellm-portable.py's .pth handling (site.addsitedir) so pywintypes - which
# pywin32.pth exposes - is importable.
$script:RuntimeVerifyExpression = "import os,site; site.addsitedir(os.environ['PYTHONPATH']); import importlib.metadata as m, prisma, pywintypes; print('LiteLLM=' + m.version('litellm')); print('Prisma=' + prisma.__version__); print('pywin32=' + m.version('pywin32'))"

# Raw import check right after install: litellm and prisma sit directly on PYTHONPATH.
$script:RuntimeImportExpression = "import importlib.metadata as m; import litellm, prisma; print('LiteLLM=' + m.version('litellm')); print('Prisma=' + prisma.__version__); print('pywin32=' + m.version('pywin32')); print('LiteLLMPath=' + litellm.__file__)"

# Prints the installed prisma-client-python version.
$script:PrismaClientVersionExpression = "import importlib.metadata as m; print(m.version('prisma'))"

# Optional MCP availability probe. Reported as a warning, never fatal, because LiteLLM moves
# these internal module paths between releases.
$script:McpProbeExpression = "from litellm.proxy.management_endpoints import mcp_management_endpoints as x; print('MCP_AVAILABLE=' + str(x.MCP_AVAILABLE))"

# ===========================================================================
# Platform helpers
# ===========================================================================

function Test-WindowsPlatform {
    [CmdletBinding()]
    [OutputType([bool])]
    param()

    # Read the Core-only automatic variable indirectly so strict mode stays safe on 5.1.
    $isWindowsVariable = Get-Variable -Name 'IsWindows' -ErrorAction SilentlyContinue

    if ($null -ne $isWindowsVariable) {
        return [bool]$isWindowsVariable.Value
    }

    return $env:OS -eq 'Windows_NT'
}

function Assert-WindowsPlatform {
    [CmdletBinding()]
    param()

    if (-not (Test-WindowsPlatform)) {
        throw [System.PlatformNotSupportedException]::new(
            'deploy-litellm-win.ps1 supports Windows only. Use deploy-litellm-linux.ps1 on Linux.'
        )
    }
}

function Set-ConsoleOutputUtf8 {
    [CmdletBinding()]
    [OutputType([System.Text.Encoding])]
    param()

    # PYTHONUTF8=1 / PYTHONIOENCODING=utf-8 make Python emit UTF-8; PowerShell decodes a native
    # command's stdout with [Console]::OutputEncoding, which defaults to the legacy OEM code page
    # on Windows PowerShell 5.1. Without this, the LiteLLM banner and any non-ASCII log text
    # render as mojibake. Returns the previous encoding so the caller can restore it.
    try {
        $previous = [Console]::OutputEncoding
        [Console]::OutputEncoding = New-Object System.Text.UTF8Encoding($false)
        return $previous
    }
    catch {
        # No real console (redirected output, some hosts) - nothing to do.
        return $null
    }
}

function Get-WindowsTargetLabel {
    [CmdletBinding()]
    [OutputType([string])]
    param()

    # Stage: architecture selection. The bundled payloads are x64. Resolve the real host
    # architecture even when a 32-bit PowerShell runs on a 64-bit operating system.
    $architecture = $env:PROCESSOR_ARCHITECTURE
    $wow64Architecture = [System.Environment]::GetEnvironmentVariable('PROCESSOR_ARCHITEW6432')

    if (-not [string]::IsNullOrWhiteSpace($wow64Architecture)) {
        $architecture = $wow64Architecture
    }

    if ([string]::IsNullOrWhiteSpace($architecture)) {
        $architecture = 'UNKNOWN'
    }

    $normalizedArchitecture = $architecture.ToUpperInvariant()

    if ($normalizedArchitecture -eq 'AMD64') {
        return 'windows-x86_64'
    }

    if ($normalizedArchitecture -eq 'ARM64') {
        Write-Warning 'ARM64 host detected. The bundled x64 runtimes will run under Windows x64 emulation.'
        return 'windows-x86_64'
    }

    throw [System.PlatformNotSupportedException]::new(
        "Unsupported processor architecture '$architecture'. This deployment requires an x64 (AMD64) or ARM64 Windows host."
    )
}

# ===========================================================================
# Environment snapshot and restoration
# ===========================================================================

function Get-EnvironmentSnapshot {
    [CmdletBinding()]
    [OutputType([hashtable])]
    param()

    $snapshot = @{}

    foreach ($entry in [System.Environment]::GetEnvironmentVariables([System.EnvironmentVariableTarget]::Process).GetEnumerator()) {
        $snapshot[[string]$entry.Key] = [string]$entry.Value
    }

    return $snapshot
}

function Restore-EnvironmentSnapshot {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [hashtable]$Snapshot
    )

    # Stage: recovery. Drop variables this run added, then restore prior values.
    $currentNames = @(Get-ChildItem -Path 'Env:' | Select-Object -ExpandProperty 'Name')

    foreach ($name in $currentNames) {
        if (-not $Snapshot.ContainsKey($name)) {
            [System.Environment]::SetEnvironmentVariable($name, $null, [System.EnvironmentVariableTarget]::Process)
        }
    }

    foreach ($name in $Snapshot.Keys) {
        [System.Environment]::SetEnvironmentVariable($name, $Snapshot[$name], [System.EnvironmentVariableTarget]::Process)
    }
}

# ===========================================================================
# Runtime slug and active-runtime state
# ===========================================================================

function Get-RuntimeSlug {
    [CmdletBinding()]
    [OutputType([string])]
    param(
        [Parameter(Mandatory = $true)]
        [string]$LiteLLMVersion
    )

    $sanitized = ($LiteLLMVersion -replace '[^0-9A-Za-z._+-]', '_')
    return "litellm-$sanitized"
}

function Read-ActiveRuntimeState {
    [CmdletBinding()]
    [OutputType([pscustomobject])]
    param(
        [Parameter(Mandatory = $true)]
        [string]$Root
    )

    $statePath = Join-Path $Root $script:ActiveRuntimeStateRelativePath

    if (-not (Test-Path -LiteralPath $statePath)) {
        return $null
    }

    try {
        $parsed = (Get-Content -LiteralPath $statePath -Raw | ConvertFrom-Json)
    }
    catch {
        return $null
    }

    foreach ($field in @('active', 'previous', 'history')) {
        if (-not $parsed.PSObject.Properties[$field]) {
            Add-Member -InputObject $parsed -NotePropertyName $field -NotePropertyValue $null -Force
        }
    }

    if ($null -eq $parsed.history) {
        $parsed.history = @()
    }

    return $parsed
}

function Write-ActiveRuntimeState {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$Root,

        [Parameter(Mandatory = $true)]
        [string]$Active,

        [Parameter()]
        [AllowNull()]
        [string]$Previous,

        [Parameter()]
        [string[]]$History = @()
    )

    $stateObject = [pscustomobject]@{
        active     = $Active
        previous   = $Previous
        history    = @($History)
        updatedUtc = (Get-Date).ToUniversalTime().ToString('o')
    }

    Write-BoxTextFile -Path (Join-Path $Root $script:ActiveRuntimeStateRelativePath) -Content ($stateObject | ConvertTo-Json -Depth 5)
}

function Set-ActiveRuntime {
    [CmdletBinding()]
    [OutputType([string])]
    param(
        [Parameter(Mandatory = $true)]
        [string]$Root,

        [Parameter(Mandatory = $true)]
        [string]$Slug
    )

    # Records Slug as active. "previous" points at the runtime being switched away from;
    # re-activating the current runtime leaves it untouched. Returns the previous slug.
    $state = Read-ActiveRuntimeState -Root $Root

    $priorActive = $null
    $priorPrevious = $null
    $priorHistory = @()

    if ($null -ne $state) {
        $priorActive = $state.active
        $priorPrevious = $state.previous
        $priorHistory = @($state.history)
    }

    $previous = $priorPrevious
    if (-not [string]::IsNullOrWhiteSpace($priorActive) -and $priorActive -ne $Slug) {
        $previous = $priorActive
    }

    $history = @($Slug) + @($priorHistory | Where-Object { "$_" -ne $Slug -and -not [string]::IsNullOrWhiteSpace($_) })
    $historyCap = [Math]::Max($script:RuntimeHistoryLimit, 2)
    $history = @($history | Select-Object -First $historyCap)

    Write-ActiveRuntimeState -Root $Root -Active $Slug -Previous $previous -History $history

    return $previous
}

function Get-ActiveRuntimeSlug {
    [CmdletBinding()]
    [OutputType([string])]
    param(
        [Parameter(Mandatory = $true)]
        [string]$Root,

        [Parameter()]
        [switch]$AllowMissing
    )

    $state = Read-ActiveRuntimeState -Root $Root

    if ($null -ne $state -and -not [string]::IsNullOrWhiteSpace($state.active)) {
        return [string]$state.active
    }

    if ($AllowMissing) {
        return $null
    }

    throw [System.InvalidOperationException]::new('No active runtime found. Run -Action Deploy first.')
}

# ===========================================================================
# Portable context
# ===========================================================================

function New-PortableContext {
    [CmdletBinding()]
    [OutputType([pscustomobject])]
    param(
        [Parameter(Mandatory = $true)]
        [string]$TargetTriple,

        [Parameter()]
        [AllowNull()]
        [string]$RuntimeSlug
    )

    # Stage: input normalization. Anchor every path to the resolved box root.
    $root = [System.IO.Path]::GetFullPath($ContainerRoot)

    $cacheDirectory = Join-Path $root 'cache'
    $binDirectory = Join-Path $root 'bin'

    $scriptFileName = 'deploy-litellm-win.ps1'
    if (-not [string]::IsNullOrWhiteSpace($PSCommandPath)) {
        $scriptFileName = [System.IO.Path]::GetFileName($PSCommandPath)
    }

    $resolvedUvDownloadUrl = $UvDownloadUrl
    if ([string]::IsNullOrWhiteSpace($resolvedUvDownloadUrl)) {
        $resolvedUvDownloadUrl = "https://github.com/astral-sh/uv/releases/download/$UvVersion/uv-x86_64-pc-windows-msvc.zip"
    }

    $resolvedPostgresDownloadUrl = $PostgresDownloadUrl
    if ([string]::IsNullOrWhiteSpace($resolvedPostgresDownloadUrl)) {
        $resolvedPostgresDownloadUrl = "https://get.enterprisedb.com/postgresql/postgresql-$PostgresVersion-windows-x64-binaries.zip"
    }

    $encodedPassword = [System.Uri]::EscapeDataString($PostgresPassword)
    $databaseUrl = "postgresql://$PostgresUser`:$encodedPassword@$PostgresHostAddress`:$PostgresPort/$PostgresDatabase"

    # Runtime-scoped paths. Null slug (Stop / Status before any deploy) leaves these null.
    $runtimeDirectory = $null
    $pythonInstallDirectory = $null
    $packagesDirectory = $null
    $prismaCacheDirectory = $null
    $manifest = $null

    if (-not [string]::IsNullOrWhiteSpace($RuntimeSlug)) {
        $runtimeDirectory = Join-Path $root (Join-Path 'runtimes' $RuntimeSlug)
        $pythonInstallDirectory = Join-Path $runtimeDirectory 'python'
        $packagesDirectory = Join-Path $runtimeDirectory 'packages'
        $prismaCacheDirectory = Join-Path $runtimeDirectory 'prisma'

        $manifestPath = Join-Path $runtimeDirectory 'manifest.json'
        if (Test-Path -LiteralPath $manifestPath) {
            try {
                $manifest = (Get-Content -LiteralPath $manifestPath -Raw | ConvertFrom-Json)
            }
            catch {
                $manifest = $null
            }
        }
    }

    # Prisma pins: explicit override wins, then the runtime manifest, then empty (derived later).
    $effectivePrismaPython = $PrismaPythonVersion
    $effectivePrismaPythonSource = $(if ([string]::IsNullOrWhiteSpace($PrismaPythonVersion)) { '' } else { 'override' })
    $effectivePrismaCli = $PrismaCliVersion
    $effectivePrismaEngine = $PrismaEngineVersion
    $effectivePrismaNode = $PrismaNodeVersion

    if ($null -ne $manifest) {
        if ([string]::IsNullOrWhiteSpace($effectivePrismaPython) -and $manifest.PSObject.Properties['prismaPython']) {
            $effectivePrismaPython = [string]$manifest.prismaPython
        }
        if ([string]::IsNullOrWhiteSpace($effectivePrismaPythonSource) -and $manifest.PSObject.Properties['prismaPythonSource']) {
            $effectivePrismaPythonSource = [string]$manifest.prismaPythonSource
        }
        if ([string]::IsNullOrWhiteSpace($effectivePrismaCli) -and $manifest.PSObject.Properties['prismaCli']) {
            $effectivePrismaCli = [string]$manifest.prismaCli
        }
        if ([string]::IsNullOrWhiteSpace($effectivePrismaEngine) -and $manifest.PSObject.Properties['prismaEngine']) {
            $effectivePrismaEngine = [string]$manifest.prismaEngine
        }
        if ([string]::IsNullOrWhiteSpace($effectivePrismaNode) -and $manifest.PSObject.Properties['node']) {
            $effectivePrismaNode = [string]$manifest.node
        }
    }

    return [pscustomobject]@{
        Root                     = $root
        HomeDir                  = Join-Path $root 'home'
        DataDir                  = Join-Path $root 'data'
        DataRoamingDir           = Join-Path $root 'data\roaming'
        DataLocalDir             = Join-Path $root 'data\local'
        CacheDir                 = $cacheDirectory
        StateDir                 = Join-Path $root 'state'
        TempDir                  = Join-Path $root 'temp'
        BinDir                   = $binDirectory
        RuntimesDir              = Join-Path $root 'runtimes'
        UvExe                    = Join-Path $root 'uv.exe'
        UvCacheDir               = Join-Path $cacheDirectory 'uv'
        PgHome                   = Join-Path $root 'postgresql'
        PgBin                    = Join-Path $root 'postgresql\bin'
        PgData                   = Join-Path $root 'data\postgresql'
        PostgresLogPath          = Join-Path $root 'data\postgresql.log'
        ConfigPath               = Join-Path $root $script:ConfigRelativePath
        ActiveRuntimeStatePath   = Join-Path $root $script:ActiveRuntimeStateRelativePath
        DeployCompleteMarkerPath = Join-Path $root $script:DeployCompleteMarkerRelativePath
        PortablePrismaPath       = Join-Path $binDirectory 'portable_prisma.py'
        LiteLLMBootstrapPath     = Join-Path $binDirectory 'litellm-portable.py'
        DatabaseSetupScriptPath  = Join-Path $binDirectory 'setup-litellm-database.py'
        CreateDatabaseSqlPath    = Join-Path $binDirectory 'create-litellm-database.sql'
        PrismaClientPyShimPath   = Join-Path $binDirectory 'prisma-client-py.cmd'
        StartCommandPath         = Join-Path $root 'start-litellm.cmd'
        StopCommandPath          = Join-Path $root 'stop-litellm.cmd'
        RuntimeCommonScriptPath  = Join-Path $binDirectory 'litellm-runtime-common.ps1'
        StartRuntimeScriptPath   = Join-Path $binDirectory 'litellm-start-runtime.ps1'
        StopRuntimeScriptPath    = Join-Path $binDirectory 'litellm-stop-runtime.ps1'
        ScriptFileName           = $scriptFileName
        RuntimeSlug              = $RuntimeSlug
        RuntimeDir               = $runtimeDirectory
        RuntimeManifestPath      = $(if ($null -ne $runtimeDirectory) { Join-Path $runtimeDirectory 'manifest.json' } else { $null })
        PythonInstallDir         = $pythonInstallDirectory
        PackagesDir              = $packagesDirectory
        PrismaCacheDir           = $prismaCacheDirectory
        PrismaBinaryCacheDir     = $(if ($null -ne $prismaCacheDirectory) { Join-Path $prismaCacheDirectory 'binaries' } else { $null })
        PrismaNodeenvCacheDir    = $(if ($null -ne $prismaCacheDirectory) { Join-Path $prismaCacheDirectory 'nodeenv' } else { $null })
        PrismaNpmCacheDir        = $(if ($null -ne $prismaCacheDirectory) { Join-Path $prismaCacheDirectory 'npm' } else { $null })
        PrismaCliPath            = $(if ($null -ne $prismaCacheDirectory) { Join-Path $prismaCacheDirectory 'binaries\node_modules\.bin\prisma.cmd' } else { $null })
        PrismaNodeExe            = $(if ($null -ne $prismaCacheDirectory) { Join-Path $prismaCacheDirectory 'nodeenv\Scripts\node.exe' } else { $null })
        PrismaCliIndexJs         = $(if ($null -ne $prismaCacheDirectory) { Join-Path $prismaCacheDirectory 'binaries\node_modules\prisma\build\index.js' } else { $null })
        PrismaQueryEnginePath    = $(if ($null -ne $prismaCacheDirectory) { Join-Path $prismaCacheDirectory 'query-engine.exe' } else { $null })
        PostgresHostAddress      = $PostgresHostAddress
        PostgresPort             = $PostgresPort
        PostgresDatabase         = $PostgresDatabase
        PostgresUser             = $PostgresUser
        PostgresPassword         = $PostgresPassword
        LiteLLMHostAddress       = $LiteLLMHostAddress
        LiteLLMPort              = $LiteLLMPort
        LiteLLMMasterKey         = $LiteLLMMasterKey
        StoreModelInDb           = $StoreModelInDb
        UpstreamModel            = $UpstreamModel
        UpstreamApiBase          = $UpstreamApiBase
        DatabaseUrl              = $databaseUrl
        TargetTriple             = $TargetTriple
        UvDownloadUrl            = $resolvedUvDownloadUrl
        PostgresDownloadUrl      = $resolvedPostgresDownloadUrl
        UvVersion                = $UvVersion
        UvHttpTimeout            = $UvHttpTimeout
        UvHttpRetries            = $UvHttpRetries
        UvConcurrentDownloads    = $UvConcurrentDownloads
        PythonVersion            = $PythonVersion
        LiteLLMVersion           = $LiteLLMVersion
        PyWin32Version           = $PyWin32Version
        PostgresVersion          = $PostgresVersion
        PrismaPythonVersion      = $effectivePrismaPython
        PrismaPythonSource       = $effectivePrismaPythonSource
        PrismaCliVersion         = $effectivePrismaCli
        PrismaEngineVersion      = $effectivePrismaEngine
        PrismaNodeVersion        = $effectivePrismaNode
    }
}

function Get-PortablePythonExe {
    [CmdletBinding()]
    [OutputType([string])]
    param(
        [Parameter(Mandatory = $true)]
        [pscustomobject]$Context,

        [Parameter()]
        [switch]$AllowMissing
    )

    # uv names its managed CPython directory "cpython-<version>-windows-x86_64-none"; the
    # interpreter is python.exe at that directory's root.
    $candidates = @()

    if ($null -ne $Context.PythonInstallDir -and (Test-Path -LiteralPath $Context.PythonInstallDir)) {
        $candidates = @(
            Get-ChildItem -LiteralPath $Context.PythonInstallDir -Directory -Filter 'cpython-*' -ErrorAction SilentlyContinue |
                ForEach-Object { Join-Path $_.FullName 'python.exe' } |
                Where-Object { Test-Path -LiteralPath $_ }
        )
    }

    if ($candidates.Count -eq 0) {
        if ($AllowMissing) {
            return $null
        }

        throw [System.IO.FileNotFoundException]::new("Portable Python not found for runtime '$($Context.RuntimeSlug)'.")
    }

    return (@($candidates | Sort-Object))[-1]
}

function Set-PortableProcessEnvironment {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [pscustomobject]$Context,

        [Parameter()]
        [switch]$RuntimeMode
    )

    # Stage: state mutation. All changes are process-local.
    $env:HOME = $Context.HomeDir
    $env:USERPROFILE = $Context.HomeDir
    $env:APPDATA = $Context.DataRoamingDir
    $env:LOCALAPPDATA = $Context.DataLocalDir
    $env:TEMP = $Context.TempDir
    $env:TMP = $Context.TempDir

    $env:XDG_CONFIG_HOME = $Context.StateDir
    $env:XDG_DATA_HOME = $Context.DataDir
    $env:XDG_STATE_HOME = $Context.StateDir
    $env:XDG_CACHE_HOME = $Context.CacheDir

    $env:UV_CACHE_DIR = $Context.UvCacheDir
    $env:UV_PYTHON_NO_REGISTRY = '1'
    $env:UV_PYTHON_INSTALL_REGISTRY = '0'
    $env:UV_PYTHON_INSTALL_BIN = '0'
    $env:UV_MANAGED_PYTHON = '1'
    $env:UV_NO_CONFIG = '1'

    # Network resilience: this profile is expected to run on thin / lossy links.
    $env:UV_HTTP_TIMEOUT = [string]$Context.UvHttpTimeout
    $env:UV_HTTP_RETRIES = [string]$Context.UvHttpRetries
    $env:UV_CONCURRENT_DOWNLOADS = [string]$Context.UvConcurrentDownloads

    $env:npm_config_fetch_timeout = [string]($Context.UvHttpTimeout * 1000)
    $env:npm_config_fetch_retries = [string]$Context.UvHttpRetries
    $env:npm_config_fetch_retry_maxtimeout = [string]($Context.UvHttpTimeout * 1000)

    $env:PYTHONNOUSERSITE = '1'
    $env:PYTHONUTF8 = '1'
    $env:PYTHONIOENCODING = 'utf-8'

    $env:PG_HOME = $Context.PgHome
    $env:PG_BIN = $Context.PgBin
    $env:PG_DATA = $Context.PgData
    $env:PGHOST = $Context.PostgresHostAddress
    $env:PGPORT = [string]$Context.PostgresPort

    $env:DATABASE_URL = $Context.DatabaseUrl

    $env:LITELLM_HOST = $Context.LiteLLMHostAddress
    $env:LITELLM_PORT = [string]$Context.LiteLLMPort
    $env:LITELLM_MASTER_KEY = $Context.LiteLLMMasterKey
    $env:LITELLM_DISABLE_NO_REDIS_WARNING = 'true'

    if ($Context.StoreModelInDb) {
        # Let models be added / edited from the admin UI and persisted to PostgreSQL.
        $env:STORE_MODEL_IN_DB = 'True'
    }

    $env:PRISMA_HOME_DIR = $Context.HomeDir
    $env:PRISMA_USE_GLOBAL_NODE = 'False'
    $env:PRISMA_USE_NODEJS_BIN = 'False'
    $env:PRISMA_OFFLINE_MODE = 'true'
    $env:PRISMA_HEALTH_WATCHDOG_ENABLED = 'false'

    # Runtime-scoped variables. Absent for Stop / Status before any deployment.
    if ($null -ne $Context.RuntimeDir) {
        $env:UV_PYTHON_INSTALL_DIR = $Context.PythonInstallDir
        $env:PYTHONPATH = $Context.PackagesDir
        $env:PRISMA_BINARY_CACHE_DIR = $Context.PrismaBinaryCacheDir
        $env:PRISMA_NODEENV_CACHE_DIR = $Context.PrismaNodeenvCacheDir
        $env:PRISMA_CLI_PATH = $Context.PrismaCliPath
        $env:NPM_CONFIG_CACHE = $Context.PrismaNpmCacheDir

        # Build-time Prisma must be allowed to download its normal engine. Runtime consumers use
        # only the portable copy, after Install-PrismaToolchain has created and verified it.
        if ($RuntimeMode) {
            if (-not (Test-Path -LiteralPath $Context.PrismaQueryEnginePath -PathType Leaf)) {
                throw [System.IO.FileNotFoundException]::new(
                    "Portable Prisma query engine missing: $($Context.PrismaQueryEnginePath)")
            }
            $env:PRISMA_QUERY_ENGINE_BINARY = $Context.PrismaQueryEnginePath
        }
        else {
            Remove-Item Env:PRISMA_QUERY_ENGINE_BINARY -ErrorAction SilentlyContinue
        }

        # Consumed by the generated helper files so they stay version-agnostic.
        $env:PORTABLE_PRISMA_NODE = $Context.PrismaNodeExe
        $env:PORTABLE_PRISMA_JS = $Context.PrismaCliIndexJs

        $pythonExe = Get-PortablePythonExe -Context $Context -AllowMissing
        if ($null -ne $pythonExe) {
            $env:PORTABLE_PYTHON_EXE = $pythonExe
        }

        if (-not [string]::IsNullOrWhiteSpace($Context.PrismaCliVersion)) {
            $env:PRISMA_VERSION = $Context.PrismaCliVersion
        }
        if (-not [string]::IsNullOrWhiteSpace($Context.PrismaEngineVersion)) {
            $env:PRISMA_EXPECTED_ENGINE_VERSION = $Context.PrismaEngineVersion
        }
    }

    # Stage: isolation. Replace PATH with the box binaries plus the minimum Windows system
    # directories so no global Python, Node, npm, or PostgreSQL is discoverable.
    $isolatedPathEntries = @(
        $Context.BinDir,
        $Context.PgBin,
        (Join-Path $env:SystemRoot 'System32'),
        $env:SystemRoot,
        (Join-Path $env:SystemRoot 'System32\WindowsPowerShell\v1.0')
    )

    $env:PATH = $isolatedPathEntries -join ';'
}

# ===========================================================================
# Low-level helpers
# ===========================================================================

function Write-SectionBanner {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$Title
    )

    Write-Host ''
    Write-Host '============================================================'
    Write-Host ('  ' + $Title)
    Write-Host '============================================================'
}

function Write-StageBanner {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$Name
    )

    Write-Host ''
    Write-Host '------------------------------------------------------------'
    Write-Host ('[RUN] ' + $Name)
    Write-Host '------------------------------------------------------------'
}

function Write-BoxTextFile {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$Path,

        [Parameter(Mandatory = $true)]
        [AllowEmptyString()]
        [string]$Content
    )

    # Stage: filesystem write. Emit UTF-8 without a byte-order mark and normalize to LF endings
    # for Python, SQL, YAML, and JSON.
    $normalizedContent = ($Content -replace "`r`n", "`n")
    $utf8WithoutBom = New-Object System.Text.UTF8Encoding($false)
    [System.IO.File]::WriteAllText($Path, $normalizedContent, $utf8WithoutBom)
}

function Write-BoxCommandFile {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$Path,

        [Parameter(Mandatory = $true)]
        [AllowEmptyString()]
        [string]$Content
    )

    # Stage: filesystem write. cmd.exe requires CRLF line endings and an OEM/ASCII-compatible
    # encoding.
    $normalizedContent = ($Content -replace "`r`n", "`n") -replace "`n", "`r`n"
    [System.IO.File]::WriteAllText($Path, $normalizedContent, [System.Text.Encoding]::ASCII)
}

function Invoke-NativeCommand {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$FilePath,

        [Parameter()]
        [string[]]$ArgumentList = @(),

        [Parameter()]
        [int[]]$SuccessExitCode = @(0),

        [Parameter()]
        [switch]$PassThruExitCode
    )

    # Stage: process call. Resolve once, pass arguments as data, invoke once. Out-Host keeps the
    # child's stdout on the console (streamed live) and OUT of this function's pipeline output,
    # so callers that assign the result get a clean value.
    if (-not (Test-Path -LiteralPath $FilePath)) {
        throw [System.IO.FileNotFoundException]::new("Executable not found: $FilePath")
    }

    & $FilePath @ArgumentList | Out-Host
    $observedExitCode = $LASTEXITCODE

    if ($PassThruExitCode) {
        return $observedExitCode
    }

    # Stage: native result validation. Never infer success from output text.
    if ($SuccessExitCode -notcontains $observedExitCode) {
        $fileName = [System.IO.Path]::GetFileName($FilePath)
        throw [System.InvalidOperationException]::new("Native command '$fileName' failed with exit code $observedExitCode.")
    }
}

function Set-SecurityProtocol {
    [CmdletBinding()]
    param()

    # Windows PowerShell 5.1 (Desktop) does not negotiate TLS 1.2 by default; GitHub and
    # EnterpriseDB require it.
    if ($PSVersionTable.PSEdition -eq 'Desktop') {
        $currentProtocol = [System.Net.ServicePointManager]::SecurityProtocol
        [System.Net.ServicePointManager]::SecurityProtocol = $currentProtocol -bor [System.Net.SecurityProtocolType]::Tls12
    }
}

function Get-ExpectedSha256 {
    [CmdletBinding()]
    [OutputType([string])]
    param(
        [Parameter(Mandatory = $true)]
        [string]$ChecksumUri
    )

    # Stage: best-effort verification material fetch. A missing sidecar returns $null.
    try {
        Set-SecurityProtocol

        $previousProgressPreference = $ProgressPreference
        $ProgressPreference = 'SilentlyContinue'

        try {
            $checksumResponse = Invoke-WebRequest -Uri $ChecksumUri -UseBasicParsing -ErrorAction Stop
        }
        finally {
            $ProgressPreference = $previousProgressPreference
        }

        $rawContent = $checksumResponse.Content
        if ($rawContent -is [byte[]]) {
            $rawContent = [System.Text.Encoding]::UTF8.GetString($rawContent)
        }

        $firstToken = (([string]$rawContent).Trim() -split '\s+')[0]

        if ($firstToken -match '^[0-9a-fA-F]{64}$') {
            return $firstToken.ToUpperInvariant()
        }

        return $null
    }
    catch {
        return $null
    }
}

function Save-RemoteFile {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$Uri,

        [Parameter(Mandatory = $true)]
        [string]$DestinationPath,

        [Parameter()]
        [string]$ChecksumUri,

        [Parameter()]
        [switch]$NoChecksumWarning
    )

    Set-SecurityProtocol

    $previousProgressPreference = $ProgressPreference
    $ProgressPreference = 'SilentlyContinue'

    $requestParameters = @{
        Uri             = $Uri
        OutFile         = $DestinationPath
        UseBasicParsing = $true
        TimeoutSec      = 600
        ErrorAction     = 'Stop'
    }

    # Stage: network call with retry - this profile targets thin / lossy links.
    $maxAttempts = 4

    try {
        Write-Host ('[DOWNLOAD] ' + $Uri)

        for ($attempt = 1; $attempt -le $maxAttempts; $attempt++) {
            try {
                Remove-Item -LiteralPath $DestinationPath -Force -ErrorAction Ignore
                Invoke-WebRequest @requestParameters
                break
            }
            catch {
                # A 4xx (missing tag, missing file) is deterministic - fail fast, do not retry.
                $statusCode = 0
                try {
                    $statusCode = [int]$_.Exception.Response.StatusCode
                }
                catch {
                    $statusCode = 0
                }

                if (($statusCode -ge 400 -and $statusCode -lt 500) -or $attempt -ge $maxAttempts) {
                    throw
                }

                $backoffSeconds = [Math]::Min(30, 5 * $attempt)
                Write-Warning ("Download attempt {0}/{1} failed: {2}. Retrying in {3}s..." -f `
                        $attempt, $maxAttempts, $_.Exception.Message, $backoffSeconds)
                Start-Sleep -Seconds $backoffSeconds
            }
        }
    }
    finally {
        $ProgressPreference = $previousProgressPreference
    }

    if (-not (Test-Path -LiteralPath $DestinationPath)) {
        throw [System.IO.FileNotFoundException]::new("Download did not produce a file: $DestinationPath")
    }

    # Stage: integrity verification against the publisher checksum when one is offered.
    if (-not [string]::IsNullOrWhiteSpace($ChecksumUri)) {
        $expectedHash = Get-ExpectedSha256 -ChecksumUri $ChecksumUri

        if ($null -ne $expectedHash) {
            $actualHash = (Get-FileHash -LiteralPath $DestinationPath -Algorithm SHA256).Hash

            if ($actualHash -ne $expectedHash) {
                Remove-Item -LiteralPath $DestinationPath -Force -ErrorAction Ignore
                throw [System.IO.InvalidDataException]::new("SHA-256 mismatch for $Uri. Expected $expectedHash but computed $actualHash.")
            }

            Write-Host '[OK] SHA-256 checksum verified.'
            return
        }

        Write-Warning "Checksum material at $ChecksumUri was unavailable; continuing without verification."
        return
    }

    if (-not $NoChecksumWarning) {
        Write-Warning 'Checksum verification is not available for this download.'
    }
}

function Expand-DownloadedArchive {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$ArchivePath,

        [Parameter(Mandatory = $true)]
        [string]$DestinationPath
    )

    if (Test-Path -LiteralPath $DestinationPath) {
        Remove-Item -LiteralPath $DestinationPath -Recurse -Force
    }

    New-Item -ItemType Directory -Force -Path $DestinationPath | Out-Null
    Expand-Archive -LiteralPath $ArchivePath -DestinationPath $DestinationPath -Force
}

function Find-ArchiveExecutable {
    [CmdletBinding()]
    [OutputType([System.IO.FileInfo])]
    param(
        [Parameter(Mandatory = $true)]
        [string]$SearchRoot,

        [Parameter(Mandatory = $true)]
        [string]$FileName,

        [Parameter()]
        [scriptblock]$DirectoryFilter
    )

    $candidates = @(Get-ChildItem -LiteralPath $SearchRoot -Filter $FileName -File -Recurse)

    if ($DirectoryFilter) {
        $candidates = @($candidates | Where-Object $DirectoryFilter)
    }

    if ($candidates.Count -eq 0) {
        throw [System.IO.InvalidDataException]::new("The archive did not contain '$FileName'.")
    }

    $selected = $candidates[0]

    if (-not (Test-PathWithinContainer -CandidatePath $selected.FullName -ContainerPath $SearchRoot)) {
        throw [System.IO.InvalidDataException]::new("Archive entry escapes the extraction directory: $($selected.FullName)")
    }

    return $selected
}

function Test-PathWithinContainer {
    [CmdletBinding()]
    [OutputType([bool])]
    param(
        [Parameter(Mandatory = $true)]
        [string]$CandidatePath,

        [Parameter(Mandatory = $true)]
        [string]$ContainerPath
    )

    $separator = [System.IO.Path]::DirectorySeparatorChar
    $altSeparator = [System.IO.Path]::AltDirectorySeparatorChar

    $normalizedContainer = [System.IO.Path]::GetFullPath($ContainerPath).TrimEnd($separator, $altSeparator) + $separator
    $normalizedCandidate = [System.IO.Path]::GetFullPath($CandidatePath)

    return $normalizedCandidate.StartsWith($normalizedContainer, [System.StringComparison]::OrdinalIgnoreCase)
}

function Test-TcpEndpoint {
    [CmdletBinding()]
    [OutputType([bool])]
    param(
        [Parameter(Mandatory = $true)]
        [string]$TargetHost,

        [Parameter(Mandatory = $true)]
        [int]$Port,

        [Parameter()]
        [int]$TimeoutMilliseconds = 1500
    )

    $tcpClient = New-Object System.Net.Sockets.TcpClient

    try {
        $connectResult = $tcpClient.BeginConnect($TargetHost, $Port, $null, $null)
        $connectedInTime = $connectResult.AsyncWaitHandle.WaitOne($TimeoutMilliseconds)

        if (-not $connectedInTime) {
            return $false
        }

        $tcpClient.EndConnect($connectResult)
        return $true
    }
    catch [System.Net.Sockets.SocketException] {
        return $false
    }
    finally {
        $tcpClient.Close()
    }
}

function Remove-ContainedDirectory {
    [CmdletBinding(SupportsShouldProcess = $true)]
    param(
        [Parameter(Mandatory = $true)]
        [string]$TargetPath,

        [Parameter(Mandatory = $true)]
        [string]$ContainerPath
    )

    if (-not (Test-Path -LiteralPath $TargetPath)) {
        return
    }

    if (-not (Test-PathWithinContainer -CandidatePath $TargetPath -ContainerPath $ContainerPath)) {
        throw [System.InvalidOperationException]::new("Refusing to remove a path outside the box: $TargetPath")
    }

    $targetItem = Get-Item -LiteralPath $TargetPath -Force
    $isReparsePoint = ($targetItem.Attributes -band [System.IO.FileAttributes]::ReparsePoint) -eq [System.IO.FileAttributes]::ReparsePoint

    if ($isReparsePoint) {
        throw [System.InvalidOperationException]::new("Refusing to remove a reparse point: $TargetPath")
    }

    if ($PSCmdlet.ShouldProcess($TargetPath, 'Remove directory tree')) {
        Remove-Item -LiteralPath $TargetPath -Recurse -Force
    }
}

# ===========================================================================
# Box layout and generated artifacts
# ===========================================================================

function Initialize-SharedLayout {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [pscustomobject]$Context
    )

    foreach ($relativePath in $script:SharedLayoutDirectories) {
        New-Item -ItemType Directory -Force -Path (Join-Path $Context.Root $relativePath) | Out-Null
    }
}

function Initialize-RuntimeLayout {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [pscustomobject]$Context
    )

    New-Item -ItemType Directory -Force -Path $Context.RuntimeDir | Out-Null

    foreach ($relativePath in $script:RuntimeLayoutDirectories) {
        New-Item -ItemType Directory -Force -Path (Join-Path $Context.RuntimeDir $relativePath) | Out-Null
    }
}

function Write-PortableArtifact {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [pscustomobject]$Context
    )

    # Stage: generated helper files. Version-agnostic: paths come from environment variables set
    # by Set-PortableProcessEnvironment, so they serve whichever runtime is active.
    $portablePrismaPython = @'
import os
import subprocess
from pathlib import Path

_node = os.environ.get("PORTABLE_PRISMA_NODE")
_js = os.environ.get("PORTABLE_PRISMA_JS")

_original_run = subprocess.run


def _same_path(left: str, right: str) -> bool:
    try:
        return os.path.normcase(os.path.abspath(left)) == os.path.normcase(
            os.path.abspath(right)
        )
    except (OSError, TypeError, ValueError):
        return False


def _portable_subprocess_run(args, *popenargs, **kwargs):
    if _node and _js and isinstance(args, (list, tuple)) and args:
        executable = os.fspath(args[0])
        configured_prisma = os.environ.get("PRISMA_CLI_PATH", "")
        stem = os.path.splitext(os.path.basename(executable))[0].lower()

        is_prisma = stem == "prisma" or (
            configured_prisma and _same_path(executable, configured_prisma)
        )

        if is_prisma:
            if not Path(_node).is_file():
                raise FileNotFoundError(f"Portable Prisma Node runtime not found: {_node}")
            if not Path(_js).is_file():
                raise FileNotFoundError(f"Portable Prisma CLI JS not found: {_js}")

            args = [str(_node), str(_js), *[str(arg) for arg in args[1:]]]

    return _original_run(args, *popenargs, **kwargs)


def patch_subprocess() -> None:
    if not _node or not _js:
        return
    if getattr(subprocess.run, "_litellm_portable_patch", False):
        return

    _portable_subprocess_run._litellm_portable_patch = True
    subprocess.run = _portable_subprocess_run
'@

    Write-BoxTextFile -Path $Context.PortablePrismaPath -Content $portablePrismaPython

    $liteLlmBootstrapPython = @'
import os
import site

# ---------------------------------------------------------------------------
# Portable Python package bootstrap
# ---------------------------------------------------------------------------
# The active runtime's package directory is supplied through PYTHONPATH.
# Python does not process .pth files from PYTHONPATH directories. On Windows
# pywin32 uses pywin32.pth to expose win32 / win32\lib / pythonwin and to run
# pywin32_bootstrap, and LiteLLM MCP imports "mcp" which imports pywintypes,
# so process the .pth files here.
# ---------------------------------------------------------------------------

portable_packages = os.environ.get("PYTHONPATH")

if portable_packages:
    for package_dir in portable_packages.split(os.pathsep):
        package_dir = package_dir.strip()

        if package_dir and os.path.isdir(package_dir):
            site.addsitedir(package_dir)


# ---------------------------------------------------------------------------
# Portable Prisma bootstrap
# ---------------------------------------------------------------------------

from portable_prisma import patch_subprocess

patch_subprocess()


# ---------------------------------------------------------------------------
# Start LiteLLM
# ---------------------------------------------------------------------------

import litellm

litellm.run_server()
'@

    Write-BoxTextFile -Path $Context.LiteLLMBootstrapPath -Content $liteLlmBootstrapPython

    $databaseSetupPython = @'
import sys

from portable_prisma import patch_subprocess

patch_subprocess()

from litellm_proxy_extras.utils import ProxyExtrasDBManager


def main() -> int:
    print("[DB] Creating/synchronizing LiteLLM schema with prisma db push...")
    if not ProxyExtrasDBManager.setup_database(use_migrate=False):
        print("[DB] prisma db push failed")
        return 1

    print("[DB] Creating/baselining LiteLLM migration ledger...")
    if not ProxyExtrasDBManager.setup_database(use_migrate=True):
        print("[DB] prisma migrate setup failed")
        return 1

    print("[DB] LiteLLM database setup complete")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
'@

    Write-BoxTextFile -Path $Context.DatabaseSetupScriptPath -Content $databaseSetupPython

    $userIdentifier = $Context.PostgresUser.Replace('"', '""')
    $databaseIdentifier = $Context.PostgresDatabase.Replace('"', '""')
    $userLiteral = $Context.PostgresUser.Replace("'", "''")
    $databaseLiteral = $Context.PostgresDatabase.Replace("'", "''")
    $passwordLiteral = $Context.PostgresPassword.Replace("'", "''")

    $createDatabaseSql = @"
DO
`$do`$
BEGIN
    IF NOT EXISTS (SELECT FROM pg_catalog.pg_roles WHERE rolname = '$userLiteral') THEN
        CREATE ROLE "$userIdentifier" WITH LOGIN PASSWORD '$passwordLiteral';
    END IF;
END
`$do`$;

SELECT 'CREATE DATABASE "$databaseIdentifier" OWNER "$userIdentifier"'
WHERE NOT EXISTS (SELECT FROM pg_database WHERE datname = '$databaseLiteral')
\gexec
"@

    Write-BoxTextFile -Path $Context.CreateDatabaseSqlPath -Content $createDatabaseSql

    # PATH shim the Prisma Node CLI spawns directly during "prisma db push". Routed to the
    # active runtime's interpreter through PORTABLE_PYTHON_EXE.
    $prismaClientPyShim = @'
@echo off
if "%PORTABLE_PYTHON_EXE%"=="" (
    echo PORTABLE_PYTHON_EXE is not set >&2
    exit /b 1
)
"%PORTABLE_PYTHON_EXE%" -m prisma %*
exit /b %ERRORLEVEL%
'@

    Write-BoxCommandFile -Path $Context.PrismaClientPyShimPath -Content $prismaClientPyShim

    # Standalone runtime helpers (generated files, NOT this deploy script). Trimmed
    # re-implementation of state lookup, portable context resolution, process-environment
    # isolation, and PostgreSQL process control - no install/build logic. start-litellm.cmd and
    # stop-litellm.cmd (below) call these directly, so the box never depends on
    # deploy-litellm-win.ps1 being present after the deploy that built it.
    $runtimeCommonScript = @'
Set-StrictMode -Version Latest

function Read-ActiveRuntimeState {
    [CmdletBinding()]
    [OutputType([pscustomobject])]
    param(
        [Parameter(Mandatory = $true)]
        [string]$Root
    )

    $statePath = Join-Path $Root 'state\active-runtime.json'

    if (-not (Test-Path -LiteralPath $statePath)) {
        return $null
    }

    try {
        $parsed = (Get-Content -LiteralPath $statePath -Raw | ConvertFrom-Json)
    }
    catch {
        return $null
    }

    foreach ($field in @('active', 'previous', 'history')) {
        if (-not $parsed.PSObject.Properties[$field]) {
            Add-Member -InputObject $parsed -NotePropertyName $field -NotePropertyValue $null -Force
        }
    }

    return $parsed
}

function Get-ActiveRuntimeSlug {
    [CmdletBinding()]
    [OutputType([string])]
    param(
        [Parameter(Mandatory = $true)]
        [string]$Root,

        [Parameter()]
        [switch]$AllowMissing
    )

    $state = Read-ActiveRuntimeState -Root $Root

    if ($null -ne $state -and -not [string]::IsNullOrWhiteSpace($state.active)) {
        return [string]$state.active
    }

    if ($AllowMissing) {
        return $null
    }

    throw [System.InvalidOperationException]::new('No active runtime found. Deploy the box first with deploy-litellm-win.ps1 -Action Deploy.')
}

function New-PortableRuntimeContext {
    [CmdletBinding()]
    [OutputType([pscustomobject])]
    param(
        [Parameter(Mandatory = $true)]
        [string]$Root,

        [Parameter()]
        [AllowNull()]
        [string]$RuntimeSlug,

        [Parameter(Mandatory = $true)]
        [string]$PostgresHostAddress,

        [Parameter(Mandatory = $true)]
        [int]$PostgresPort,

        [Parameter(Mandatory = $true)]
        [string]$PostgresDatabase,

        [Parameter(Mandatory = $true)]
        [string]$PostgresUser,

        [Parameter(Mandatory = $true)]
        [string]$PostgresPassword,

        [Parameter(Mandatory = $true)]
        [string]$LiteLLMHostAddress,

        [Parameter(Mandatory = $true)]
        [int]$LiteLLMPort,

        [Parameter(Mandatory = $true)]
        [string]$LiteLLMMasterKey,

        [Parameter(Mandatory = $true)]
        [bool]$StoreModelInDb
    )

    $cacheDirectory = Join-Path $Root 'cache'
    $binDirectory = Join-Path $Root 'bin'

    $encodedPassword = [System.Uri]::EscapeDataString($PostgresPassword)
    $databaseUrl = "postgresql://$PostgresUser`:$encodedPassword@$PostgresHostAddress`:$PostgresPort/$PostgresDatabase"

    $runtimeDirectory = $null
    $pythonInstallDirectory = $null
    $packagesDirectory = $null
    $prismaCacheDirectory = $null
    $manifest = $null

    if (-not [string]::IsNullOrWhiteSpace($RuntimeSlug)) {
        $runtimeDirectory = Join-Path $Root (Join-Path 'runtimes' $RuntimeSlug)
        $pythonInstallDirectory = Join-Path $runtimeDirectory 'python'
        $packagesDirectory = Join-Path $runtimeDirectory 'packages'
        $prismaCacheDirectory = Join-Path $runtimeDirectory 'prisma'

        $manifestPath = Join-Path $runtimeDirectory 'manifest.json'
        if (Test-Path -LiteralPath $manifestPath) {
            try {
                $manifest = (Get-Content -LiteralPath $manifestPath -Raw | ConvertFrom-Json)
            }
            catch {
                $manifest = $null
            }
        }
    }

    $prismaCliVersion = $null
    $prismaEngineVersion = $null

    if ($null -ne $manifest) {
        if ($manifest.PSObject.Properties['prismaCli'])    { $prismaCliVersion = [string]$manifest.prismaCli }
        if ($manifest.PSObject.Properties['prismaEngine']) { $prismaEngineVersion = [string]$manifest.prismaEngine }
    }

    return [pscustomobject]@{
        Root                  = $Root
        HomeDir               = Join-Path $Root 'home'
        DataDir               = Join-Path $Root 'data'
        DataRoamingDir        = Join-Path $Root 'data\roaming'
        DataLocalDir          = Join-Path $Root 'data\local'
        CacheDir              = $cacheDirectory
        StateDir              = Join-Path $Root 'state'
        TempDir               = Join-Path $Root 'temp'
        BinDir                = $binDirectory
        PgHome                = Join-Path $Root 'postgresql'
        PgBin                 = Join-Path $Root 'postgresql\bin'
        PgData                = Join-Path $Root 'data\postgresql'
        PostgresLogPath       = Join-Path $Root 'data\postgresql.log'
        ConfigPath            = Join-Path $Root 'state\config.yaml'
        LiteLLMBootstrapPath  = Join-Path $binDirectory 'litellm-portable.py'
        RuntimeSlug           = $RuntimeSlug
        RuntimeDir            = $runtimeDirectory
        PythonInstallDir      = $pythonInstallDirectory
        PackagesDir           = $packagesDirectory
        PrismaCacheDir        = $prismaCacheDirectory
        PrismaBinaryCacheDir  = $(if ($null -ne $prismaCacheDirectory) { Join-Path $prismaCacheDirectory 'binaries' } else { $null })
        PrismaNodeenvCacheDir = $(if ($null -ne $prismaCacheDirectory) { Join-Path $prismaCacheDirectory 'nodeenv' } else { $null })
        PrismaNpmCacheDir     = $(if ($null -ne $prismaCacheDirectory) { Join-Path $prismaCacheDirectory 'npm' } else { $null })
        PrismaCliPath         = $(if ($null -ne $prismaCacheDirectory) { Join-Path $prismaCacheDirectory 'binaries\node_modules\.bin\prisma.cmd' } else { $null })
        PrismaNodeExe         = $(if ($null -ne $prismaCacheDirectory) { Join-Path $prismaCacheDirectory 'nodeenv\Scripts\node.exe' } else { $null })
        PrismaCliIndexJs      = $(if ($null -ne $prismaCacheDirectory) { Join-Path $prismaCacheDirectory 'binaries\node_modules\prisma\build\index.js' } else { $null })
        PrismaQueryEnginePath = $(if ($null -ne $prismaCacheDirectory) { Join-Path $prismaCacheDirectory 'query-engine.exe' } else { $null })
        PostgresHostAddress   = $PostgresHostAddress
        PostgresPort          = $PostgresPort
        PostgresDatabase      = $PostgresDatabase
        PostgresUser          = $PostgresUser
        PostgresPassword      = $PostgresPassword
        LiteLLMHostAddress    = $LiteLLMHostAddress
        LiteLLMPort           = $LiteLLMPort
        LiteLLMMasterKey      = $LiteLLMMasterKey
        StoreModelInDb        = $StoreModelInDb
        DatabaseUrl           = $databaseUrl
        PrismaCliVersion      = $prismaCliVersion
        PrismaEngineVersion   = $prismaEngineVersion
    }
}

function Get-PortablePythonExe {
    [CmdletBinding()]
    [OutputType([string])]
    param(
        [Parameter(Mandatory = $true)]
        [pscustomobject]$Context,

        [Parameter()]
        [switch]$AllowMissing
    )

    $candidates = @()

    if ($null -ne $Context.PythonInstallDir -and (Test-Path -LiteralPath $Context.PythonInstallDir)) {
        $candidates = @(
            Get-ChildItem -LiteralPath $Context.PythonInstallDir -Directory -Filter 'cpython-*' -ErrorAction SilentlyContinue |
                ForEach-Object { Join-Path $_.FullName 'python.exe' } |
                Where-Object { Test-Path -LiteralPath $_ }
        )
    }

    if ($candidates.Count -eq 0) {
        if ($AllowMissing) {
            return $null
        }

        throw [System.IO.FileNotFoundException]::new("Portable Python not found for runtime '$($Context.RuntimeSlug)'.")
    }

    return (@($candidates | Sort-Object))[-1]
}

function Set-PortableRuntimeEnvironment {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [pscustomobject]$Context
    )

    $env:HOME = $Context.HomeDir
    $env:USERPROFILE = $Context.HomeDir
    $env:APPDATA = $Context.DataRoamingDir
    $env:LOCALAPPDATA = $Context.DataLocalDir
    $env:TEMP = $Context.TempDir
    $env:TMP = $Context.TempDir

    $env:XDG_CONFIG_HOME = $Context.StateDir
    $env:XDG_DATA_HOME = $Context.DataDir
    $env:XDG_STATE_HOME = $Context.StateDir
    $env:XDG_CACHE_HOME = $Context.CacheDir

    $env:PYTHONNOUSERSITE = '1'
    $env:PYTHONUTF8 = '1'
    $env:PYTHONIOENCODING = 'utf-8'

    $env:PG_HOME = $Context.PgHome
    $env:PG_BIN = $Context.PgBin
    $env:PG_DATA = $Context.PgData
    $env:PGHOST = $Context.PostgresHostAddress
    $env:PGPORT = [string]$Context.PostgresPort

    $env:DATABASE_URL = $Context.DatabaseUrl

    $env:LITELLM_HOST = $Context.LiteLLMHostAddress
    $env:LITELLM_PORT = [string]$Context.LiteLLMPort
    $env:LITELLM_MASTER_KEY = $Context.LiteLLMMasterKey
    $env:LITELLM_DISABLE_NO_REDIS_WARNING = 'true'

    if ($Context.StoreModelInDb) {
        $env:STORE_MODEL_IN_DB = 'True'
    }

    $env:PRISMA_HOME_DIR = $Context.HomeDir
    $env:PRISMA_USE_GLOBAL_NODE = 'False'
    $env:PRISMA_USE_NODEJS_BIN = 'False'
    $env:PRISMA_OFFLINE_MODE = 'true'
    $env:PRISMA_HEALTH_WATCHDOG_ENABLED = 'false'

    if ($null -ne $Context.RuntimeDir) {
        $env:PYTHONPATH = $Context.PackagesDir
        $env:PRISMA_BINARY_CACHE_DIR = $Context.PrismaBinaryCacheDir
        $env:PRISMA_NODEENV_CACHE_DIR = $Context.PrismaNodeenvCacheDir
        $env:PRISMA_CLI_PATH = $Context.PrismaCliPath
        $env:PRISMA_QUERY_ENGINE_BINARY = $Context.PrismaQueryEnginePath
        $env:NPM_CONFIG_CACHE = $Context.PrismaNpmCacheDir
        $env:PORTABLE_PRISMA_NODE = $Context.PrismaNodeExe
        $env:PORTABLE_PRISMA_JS = $Context.PrismaCliIndexJs

        $pythonExe = Get-PortablePythonExe -Context $Context -AllowMissing
        if ($null -ne $pythonExe) {
            $env:PORTABLE_PYTHON_EXE = $pythonExe
        }

        if (-not [string]::IsNullOrWhiteSpace($Context.PrismaCliVersion)) {
            $env:PRISMA_VERSION = $Context.PrismaCliVersion
        }
        if (-not [string]::IsNullOrWhiteSpace($Context.PrismaEngineVersion)) {
            $env:PRISMA_EXPECTED_ENGINE_VERSION = $Context.PrismaEngineVersion
        }
    }

    $isolatedPathEntries = @(
        $Context.BinDir,
        $Context.PgBin,
        (Join-Path $env:SystemRoot 'System32'),
        $env:SystemRoot,
        (Join-Path $env:SystemRoot 'System32\WindowsPowerShell\v1.0')
    )

    $env:PATH = $isolatedPathEntries -join ';'
}

function Invoke-NativeCommand {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$FilePath,

        [Parameter()]
        [string[]]$ArgumentList = @(),

        [Parameter()]
        [int[]]$SuccessExitCode = @(0),

        [Parameter()]
        [switch]$PassThruExitCode
    )

    if (-not (Test-Path -LiteralPath $FilePath)) {
        throw [System.IO.FileNotFoundException]::new("Executable not found: $FilePath")
    }

    & $FilePath @ArgumentList | Out-Host
    $observedExitCode = $LASTEXITCODE

    if ($PassThruExitCode) {
        return $observedExitCode
    }

    if ($SuccessExitCode -notcontains $observedExitCode) {
        $fileName = [System.IO.Path]::GetFileName($FilePath)
        throw [System.InvalidOperationException]::new("Native command '$fileName' failed with exit code $observedExitCode.")
    }
}

function Test-PostgresReady {
    [CmdletBinding()]
    [OutputType([bool])]
    param(
        [Parameter(Mandatory = $true)]
        [pscustomobject]$Context
    )

    $pgIsReadyExe = Join-Path $Context.PgBin 'pg_isready.exe'

    if (-not (Test-Path -LiteralPath $pgIsReadyExe)) {
        return $false
    }

    $exitCode = Invoke-NativeCommand -FilePath $pgIsReadyExe -ArgumentList @(
        '-h', $Context.PostgresHostAddress, '-p', [string]$Context.PostgresPort, '-q') -PassThruExitCode

    return $exitCode -eq 0
}

function Invoke-PgCtl {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [pscustomobject]$Context,

        [Parameter(Mandatory = $true)]
        [string[]]$ArgumentList,

        [Parameter()]
        [int]$TimeoutSeconds = 120
    )

    $pgCtlExe = Join-Path $Context.PgBin 'pg_ctl.exe'

    if (-not (Test-Path -LiteralPath $pgCtlExe)) {
        throw [System.IO.FileNotFoundException]::new("Executable not found: $pgCtlExe")
    }

    $stdoutPath = Join-Path $Context.TempDir ('pg_ctl-out-' + [System.Guid]::NewGuid().ToString('N') + '.log')
    $stderrPath = Join-Path $Context.TempDir ('pg_ctl-err-' + [System.Guid]::NewGuid().ToString('N') + '.log')

    $startParameters = @{
        FilePath               = $pgCtlExe
        ArgumentList           = $ArgumentList
        NoNewWindow            = $true
        PassThru               = $true
        RedirectStandardOutput = $stdoutPath
        RedirectStandardError  = $stderrPath
    }

    try {
        $pgCtlProcess = Start-Process @startParameters
        $null = $pgCtlProcess.Handle
        $exitedInTime = $pgCtlProcess.WaitForExit($TimeoutSeconds * 1000)

        foreach ($outputPath in @($stdoutPath, $stderrPath)) {
            if (Test-Path -LiteralPath $outputPath) {
                $outputText = (Get-Content -LiteralPath $outputPath -Raw)
                if (-not [string]::IsNullOrWhiteSpace($outputText)) {
                    Write-Host $outputText.Trim()
                }
            }
        }

        if (-not $exitedInTime) {
            try {
                $pgCtlProcess.Kill()
            }
            catch {
                Write-Warning 'pg_ctl did not exit and could not be terminated.'
            }

            throw [System.TimeoutException]::new("pg_ctl did not finish within $TimeoutSeconds seconds.")
        }

        if ($pgCtlProcess.ExitCode -ne 0) {
            throw [System.InvalidOperationException]::new("pg_ctl failed with exit code $($pgCtlProcess.ExitCode).")
        }
    }
    finally {
        Remove-Item -LiteralPath $stdoutPath -Force -ErrorAction Ignore
        Remove-Item -LiteralPath $stderrPath -Force -ErrorAction Ignore
    }
}

function Get-PostgresLogTail {
    [CmdletBinding()]
    [OutputType([string])]
    param(
        [Parameter(Mandatory = $true)]
        [pscustomobject]$Context
    )

    if (-not (Test-Path -LiteralPath $Context.PostgresLogPath)) {
        return ''
    }

    $tailLines = @(Get-Content -LiteralPath $Context.PostgresLogPath -Tail 15)
    return "Last PostgreSQL log lines:`n" + ($tailLines -join "`n")
}

function Clear-StalePostgresLock {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [pscustomobject]$Context
    )

    $lockFile = Join-Path $Context.PgData 'postmaster.pid'

    if (-not (Test-Path -LiteralPath $lockFile)) {
        return
    }

    $lockPid = 0
    $firstLine = (Get-Content -LiteralPath $lockFile -TotalCount 1 -ErrorAction SilentlyContinue)

    if (-not [int]::TryParse($firstLine, [ref]$lockPid)) {
        return
    }

    $lockedProcess = Get-Process -Id $lockPid -ErrorAction SilentlyContinue

    if ($null -eq $lockedProcess) {
        Write-Host "[OK] Removing stale postmaster.pid (process $lockPid is not running)."
        Remove-Item -LiteralPath $lockFile -Force -ErrorAction Ignore
    }
}
function Start-PortablePostgres {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [pscustomobject]$Context
    )

    $pgVersionMarker = Join-Path $Context.PgData 'PG_VERSION'

    if (-not (Test-Path -LiteralPath $pgVersionMarker)) {
        throw [System.InvalidOperationException]::new("PostgreSQL data cluster is not initialized: $($Context.PgData)")
    }

    if (Test-PostgresReady -Context $Context) {
        Write-Host "[OK] PostgreSQL is already accepting connections on $($Context.PostgresHostAddress):$($Context.PostgresPort)."
        return
    }

    Clear-StalePostgresLock -Context $Context

    try {
        Invoke-PgCtl -Context $Context -ArgumentList @('start', '-D', $Context.PgData, '-l', $Context.PostgresLogPath, '-w') -TimeoutSeconds 120
    }
    catch {
        $logTail = Get-PostgresLogTail -Context $Context
        $message = $_.Exception.Message
        if ($logTail) {
            $message = $message + "`n" + $logTail
        }
        throw [System.InvalidOperationException]::new($message)
    }

    if (-not (Test-PostgresReady -Context $Context)) {
        $logTail = Get-PostgresLogTail -Context $Context
        $message = 'PostgreSQL did not begin accepting connections after start.'
        if ($logTail) {
            $message = $message + "`n" + $logTail
        }
        throw [System.InvalidOperationException]::new($message)
    }

    Write-Host "[OK] PostgreSQL is accepting connections on $($Context.PostgresHostAddress):$($Context.PostgresPort)."
}

function Stop-PortablePostgres {
    [CmdletBinding()]
    [OutputType([pscustomobject])]
    param(
        [Parameter(Mandatory = $true)]
        [pscustomobject]$Context
    )

    $pgVersionMarker = Join-Path $Context.PgData 'PG_VERSION'
    $pgCtlExe = Join-Path $Context.PgBin 'pg_ctl.exe'

    if (-not (Test-Path -LiteralPath $pgVersionMarker) -or -not (Test-Path -LiteralPath $pgCtlExe)) {
        Write-Host '[OK] No portable PostgreSQL cluster to stop.'
        return [pscustomobject]@{ Action = 'Stop'; PostgresStopped = $false }
    }

    if (-not (Test-PostgresReady -Context $Context)) {
        Write-Host '[OK] PostgreSQL is not running.'
        return [pscustomobject]@{ Action = 'Stop'; PostgresStopped = $false }
    }

    Invoke-PgCtl -Context $Context -ArgumentList @('stop', '-D', $Context.PgData, '-w', '-m', 'fast') -TimeoutSeconds 60
    Write-Host '[OK] PostgreSQL stopped.'
    return [pscustomobject]@{ Action = 'Stop'; PostgresStopped = $true }
}

function Start-LiteLLMProxy {
    [CmdletBinding()]
    [OutputType([pscustomobject])]
    param(
        [Parameter(Mandatory = $true)]
        [pscustomobject]$Context,

        [Parameter()]
        [string[]]$ProxyArgument
    )

    $pythonExe = Get-PortablePythonExe -Context $Context
    $env:PORTABLE_PYTHON_EXE = $pythonExe

    $pgVersionMarker = Join-Path $Context.PgData 'PG_VERSION'
    if (-not (Test-Path -LiteralPath $pgVersionMarker)) {
        throw [System.InvalidOperationException]::new('PostgreSQL data cluster is not initialized. Run -Action Deploy first.')
    }

    if (-not (Test-Path -LiteralPath $Context.ConfigPath)) {
        throw [System.IO.FileNotFoundException]::new("Config missing: $($Context.ConfigPath). Run -Action Deploy first.")
    }

    if (-not (Test-PostgresReady -Context $Context)) {
        Start-PortablePostgres -Context $Context
    }

    $argumentList = @(
        $Context.LiteLLMBootstrapPath,
        '--config', $Context.ConfigPath,
        '--host', $Context.LiteLLMHostAddress,
        '--port', [string]$Context.LiteLLMPort
    )

    if ($ProxyArgument) {
        $argumentList += $ProxyArgument
    }

    Write-Host "[RUN] LiteLLM proxy ($($Context.RuntimeSlug)) on http://$($Context.LiteLLMHostAddress):$($Context.LiteLLMPort)"
    & $pythonExe @argumentList | Out-Host
    $proxyExitCode = $LASTEXITCODE

    return [pscustomobject]@{ Action = 'Start'; ExitCode = $proxyExitCode; Root = $Context.Root; Runtime = $Context.RuntimeSlug }
}
'@

    Write-BoxTextFile -Path $Context.RuntimeCommonScriptPath -Content $runtimeCommonScript

    $startRuntimeScript = @'
[CmdletBinding()]
param(
    [Parameter()] [string]$ContainerRoot,
    [Parameter()] [string]$PostgresHostAddress = '127.0.0.1',
    [Parameter()] [int]$PostgresPort = 54321,
    [Parameter()] [string]$PostgresDatabase = 'litellm',
    [Parameter()] [string]$PostgresUser = 'litellm',
    [Parameter()] [string]$PostgresPassword = 'litellm-local',
    [Parameter()] [string]$LiteLLMHostAddress = '127.0.0.1',
    [Parameter()] [int]$LiteLLMPort = 4000,
    [Parameter()] [string]$LiteLLMMasterKey = 'sk-1234',
    [Parameter()] [bool]$StoreModelInDb = $true,
    [Parameter(ValueFromRemainingArguments = $true)]
    [string[]]$LiteLLMArgument
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
[Console]::OutputEncoding = New-Object System.Text.UTF8Encoding($false)

. (Join-Path $PSScriptRoot 'litellm-runtime-common.ps1')

if ([string]::IsNullOrWhiteSpace($ContainerRoot)) {
    $anchor = $PSScriptRoot
    if ([string]::IsNullOrWhiteSpace($anchor) -and -not [string]::IsNullOrWhiteSpace($PSCommandPath)) {
        $anchor = Split-Path -Parent $PSCommandPath
    }
    if ([string]::IsNullOrWhiteSpace($anchor)) {
        throw [System.ArgumentException]::new('Could not determine the box directory. Pass -ContainerRoot explicitly.')
    }
    $ContainerRoot = Split-Path -Parent $anchor
}

$root = [System.IO.Path]::GetFullPath($ContainerRoot)

if (-not (Test-Path -LiteralPath $root)) {
    throw [System.IO.DirectoryNotFoundException]::new("Container root does not exist: $root")
}

$slug = Get-ActiveRuntimeSlug -Root $root
$context = New-PortableRuntimeContext -Root $root -RuntimeSlug $slug `
    -PostgresHostAddress $PostgresHostAddress -PostgresPort $PostgresPort `
    -PostgresDatabase $PostgresDatabase -PostgresUser $PostgresUser -PostgresPassword $PostgresPassword `
    -LiteLLMHostAddress $LiteLLMHostAddress -LiteLLMPort $LiteLLMPort -LiteLLMMasterKey $LiteLLMMasterKey `
    -StoreModelInDb $StoreModelInDb

Set-PortableRuntimeEnvironment -Context $context

$result = Start-LiteLLMProxy -Context $context -ProxyArgument $LiteLLMArgument

if ($null -ne $result -and $result.PSObject.Properties['ExitCode']) {
    exit [int]$result.ExitCode
}

exit 0
'@

    Write-BoxTextFile -Path $Context.StartRuntimeScriptPath -Content $startRuntimeScript

    $stopRuntimeScript = @'
[CmdletBinding()]
param(
    [Parameter()] [string]$ContainerRoot,
    [Parameter()] [string]$PostgresHostAddress = '127.0.0.1',
    [Parameter()] [int]$PostgresPort = 54321,
    [Parameter()] [string]$PostgresDatabase = 'litellm',
    [Parameter()] [string]$PostgresUser = 'litellm',
    [Parameter()] [string]$PostgresPassword = 'litellm-local',
    [Parameter()] [string]$LiteLLMHostAddress = '127.0.0.1',
    [Parameter()] [int]$LiteLLMPort = 4000,
    [Parameter()] [string]$LiteLLMMasterKey = 'sk-1234',
    [Parameter()] [bool]$StoreModelInDb = $true
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

. (Join-Path $PSScriptRoot 'litellm-runtime-common.ps1')

if ([string]::IsNullOrWhiteSpace($ContainerRoot)) {
    $anchor = $PSScriptRoot
    if ([string]::IsNullOrWhiteSpace($anchor) -and -not [string]::IsNullOrWhiteSpace($PSCommandPath)) {
        $anchor = Split-Path -Parent $PSCommandPath
    }
    if ([string]::IsNullOrWhiteSpace($anchor)) {
        throw [System.ArgumentException]::new('Could not determine the box directory. Pass -ContainerRoot explicitly.')
    }
    $ContainerRoot = Split-Path -Parent $anchor
}

$root = [System.IO.Path]::GetFullPath($ContainerRoot)

if (-not (Test-Path -LiteralPath $root)) {
    throw [System.IO.DirectoryNotFoundException]::new("Container root does not exist: $root")
}

$slug = Get-ActiveRuntimeSlug -Root $root -AllowMissing
$context = New-PortableRuntimeContext -Root $root -RuntimeSlug $slug `
    -PostgresHostAddress $PostgresHostAddress -PostgresPort $PostgresPort `
    -PostgresDatabase $PostgresDatabase -PostgresUser $PostgresUser -PostgresPassword $PostgresPassword `
    -LiteLLMHostAddress $LiteLLMHostAddress -LiteLLMPort $LiteLLMPort -LiteLLMMasterKey $LiteLLMMasterKey `
    -StoreModelInDb $StoreModelInDb

Set-PortableRuntimeEnvironment -Context $context

Stop-PortablePostgres -Context $context
'@

    Write-BoxTextFile -Path $Context.StopRuntimeScriptPath -Content $stopRuntimeScript

    $startCommandTemplate = @'
@echo off
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0bin\litellm-start-runtime.ps1" %*
exit /b %ERRORLEVEL%
'@

    Write-BoxCommandFile -Path $Context.StartCommandPath -Content $startCommandTemplate

    $stopCommandTemplate = @'
@echo off
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0bin\litellm-stop-runtime.ps1" %*
exit /b %ERRORLEVEL%
'@

    Write-BoxCommandFile -Path $Context.StopCommandPath -Content $stopCommandTemplate

    Write-Host '[OK] Portable helper files, start-litellm.cmd and stop-litellm.cmd created.'
}

function Initialize-Config {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [pscustomobject]$Context
    )

    # Stage: generated configuration, written once. On later runs the user owns state\config.yaml
    # (their model_list survives every deploy and update). The master key is delivered through
    # the LITELLM_MASTER_KEY environment variable, not this file.
    if (Test-Path -LiteralPath $Context.ConfigPath) {
        Write-Host "[OK] Existing config kept: $($Context.ConfigPath)"
        return
    }

    $configYaml = @"
model_list:
  - model_name: "$($Context.UpstreamModel)"
    litellm_params:
      model: "hosted_vllm/$($Context.UpstreamModel)"
      api_base: "$($Context.UpstreamApiBase)"

general_settings:
  database_url: os.environ/DATABASE_URL
"@

    Write-BoxTextFile -Path $Context.ConfigPath -Content $configYaml
    Write-Host "[OK] Config created: $($Context.ConfigPath)"
}

# ===========================================================================
# Runtime installation stages
# ===========================================================================

function Install-Uv {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [pscustomobject]$Context
    )

    if (Test-Path -LiteralPath $Context.UvExe) {
        Write-Host '[OK] uv already present.'
        Invoke-NativeCommand -FilePath $Context.UvExe -ArgumentList @('--version')
        return
    }

    New-Item -ItemType Directory -Force -Path $Context.TempDir | Out-Null

    $stagingToken = [System.Guid]::NewGuid().ToString('N')
    $archivePath = Join-Path $Context.TempDir "uv-$stagingToken.zip"
    $extractPath = Join-Path $Context.TempDir "uv-extract-$stagingToken"

    try {
        Save-RemoteFile -Uri $Context.UvDownloadUrl -DestinationPath $archivePath -ChecksumUri ($Context.UvDownloadUrl + '.sha256')
        Expand-DownloadedArchive -ArchivePath $archivePath -DestinationPath $extractPath

        # uv ships uv.exe and uvx.exe side by side.
        $uvExecutable = Find-ArchiveExecutable -SearchRoot $extractPath -FileName 'uv.exe'
        Copy-Item -Path (Join-Path $uvExecutable.Directory.FullName '*.exe') -Destination $Context.Root -Force
    }
    finally {
        Remove-Item -LiteralPath $archivePath -Force -ErrorAction Ignore
        Remove-Item -LiteralPath $extractPath -Recurse -Force -ErrorAction Ignore
    }

    if (-not (Test-Path -LiteralPath $Context.UvExe)) {
        throw [System.IO.FileNotFoundException]::new("uv.exe was not present after extraction: $($Context.UvExe)")
    }

    Invoke-NativeCommand -FilePath $Context.UvExe -ArgumentList @('--version')
}

function Install-PortablePython {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [pscustomobject]$Context
    )

    $existingPython = Get-PortablePythonExe -Context $Context -AllowMissing

    if ($null -ne $existingPython) {
        Write-Host "[OK] Portable Python already present for $($Context.RuntimeSlug)."
        Invoke-NativeCommand -FilePath $existingPython -ArgumentList @('--version')
        return
    }

    Invoke-NativeCommand -FilePath $Context.UvExe -ArgumentList @('python', 'install', $Context.PythonVersion, '--no-registry', '--no-bin')

    $installedPython = Get-PortablePythonExe -Context $Context
    Invoke-NativeCommand -FilePath $installedPython -ArgumentList @('--version')
}

function Get-PythonOutputLines {
    [CmdletBinding()]
    [OutputType([string[]])]
    param(
        [Parameter(Mandatory = $true)]
        [string]$PythonExe,

        [Parameter(Mandatory = $true)]
        [string]$Expression
    )

    # Runs "python -c <expr>" and returns its stdout lines. Callers MUST wrap in @(): PowerShell
    # unrolls a 0- or 1-element return to $null / a scalar. Probe failures are non-fatal, so
    # relax the error preference for the merged-stream capture (5.1 wraps native stderr).
    $ErrorActionPreference = 'Continue'

    try {
        $raw = & $PythonExe -c $Expression 2>&1
        $exitCode = $LASTEXITCODE
    }
    catch {
        return @()
    }

    if ($exitCode -ne 0) {
        return @()
    }

    return @(
        $raw |
            Where-Object { $_ -isnot [System.Management.Automation.ErrorRecord] } |
            ForEach-Object { "$_".Trim() } |
            Where-Object { $_ -ne '' }
    )
}

function Read-LockedPackageVersion {
    [CmdletBinding()]
    [OutputType([string])]
    param(
        [Parameter(Mandatory = $true)]
        [string]$LockPath,

        [Parameter(Mandatory = $true)]
        [string]$PackageName
    )

    # Both uv.lock and poetry.lock use [[package]] tables with name = "..." and version = "...".
    if (-not (Test-Path -LiteralPath $LockPath)) {
        return $null
    }

    $escaped = [regex]::Escape($PackageName)
    $blocks = [regex]::Split((Get-Content -LiteralPath $LockPath -Raw), '(?m)^\[\[package\]\]\s*$')

    foreach ($block in $blocks) {
        if ($block -match ('(?m)^\s*name\s*=\s*"' + $escaped + '"\s*$')) {
            $versionMatch = [regex]::Match($block, '(?m)^\s*version\s*=\s*"([^"]+)"\s*$')
            if ($versionMatch.Success) {
                return $versionMatch.Groups[1].Value
            }
        }
    }

    return $null
}

function Get-LiteLLMLockedPackageVersion {
    [CmdletBinding()]
    [OutputType([string])]
    param(
        [Parameter(Mandatory = $true)]
        [string]$LiteLLMVersion,

        [Parameter(Mandatory = $true)]
        [string]$PackageName,

        [Parameter(Mandatory = $true)]
        [string]$CacheDir
    )

    # Reads the exact <PackageName> version from LiteLLM's committed lockfile at the release
    # tag - the version LiteLLM's own Docker image and CI are frozen to. Returns $null on any
    # failure so the caller can fall back.
    New-Item -ItemType Directory -Force -Path $CacheDir | Out-Null

    $refs = @("v$LiteLLMVersion", $LiteLLMVersion)

    foreach ($template in $script:LiteLLMLockUrlTemplates) {
        $lockName = ($template -split '/')[-1]
        $cachePath = Join-Path $CacheDir ("$lockName-$LiteLLMVersion")

        foreach ($ref in $refs) {
            if (-not (Test-Path -LiteralPath $cachePath)) {
                $url = [string]::Format($template, $ref)

                try {
                    Save-RemoteFile -Uri $url -DestinationPath $cachePath -NoChecksumWarning
                }
                catch {
                    Remove-Item -LiteralPath $cachePath -Force -ErrorAction Ignore
                    continue
                }
            }

            $version = Read-LockedPackageVersion -LockPath $cachePath -PackageName $PackageName

            if (-not [string]::IsNullOrWhiteSpace($version)) {
                Write-Host ("[OK] {0}=={1} (from LiteLLM {2}'s {3})" -f $PackageName, $version, $LiteLLMVersion, $lockName)
                return $version
            }

            Remove-Item -LiteralPath $cachePath -Force -ErrorAction Ignore
        }
    }

    return $null
}

function Resolve-PrismaPythonVersion {
    [CmdletBinding()]
    [OutputType([pscustomobject])]
    param(
        [Parameter(Mandatory = $true)]
        [pscustomobject]$Context
    )

    if (-not [string]::IsNullOrWhiteSpace($PrismaPythonVersion)) {
        return [pscustomobject]@{ Version = $PrismaPythonVersion; Source = 'override' }
    }

    $cacheDir = Join-Path $Context.Root $script:LiteLLMLockCacheRelativeDir
    $locked = Get-LiteLLMLockedPackageVersion -LiteLLMVersion $Context.LiteLLMVersion -PackageName 'prisma' -CacheDir $cacheDir

    if (-not [string]::IsNullOrWhiteSpace($locked)) {
        return [pscustomobject]@{ Version = "$locked".Trim(); Source = 'lock' }
    }

    Write-Warning ("Could not read the tested prisma version from LiteLLM {0}'s lockfile. " -f $Context.LiteLLMVersion +
        "Falling back to -PrismaPythonFallbackVersion ($PrismaPythonFallbackVersion); pass -PrismaPythonVersion to pin explicitly.")
    return [pscustomobject]@{ Version = $PrismaPythonFallbackVersion; Source = 'fallback' }
}

function Resolve-PrismaPins {
    [CmdletBinding()]
    [OutputType([pscustomobject])]
    param(
        [Parameter(Mandatory = $true)]
        [pscustomobject]$Context,

        [Parameter(Mandatory = $true)]
        [string]$PythonExe
    )

    # Prisma CLI version + engine hash: left UNSET unless the caller overrides, so
    # prisma-client-python uses its own internal default (the exact CLI + engine that release
    # was built against). Node.js follows the CLI major - Prisma 5.x supports Node 20.
    $prismaClientVersion = ''
    $clientLines = @(Get-PythonOutputLines -PythonExe $PythonExe -Expression $script:PrismaClientVersionExpression)
    if ($clientLines.Count -ge 1) {
        $prismaClientVersion = "$($clientLines[0])".Trim()
    }

    $effectiveCli = $PrismaCliVersion
    $effectiveEngine = $PrismaEngineVersion

    $effectiveNode = $PrismaNodeVersion
    if ([string]::IsNullOrWhiteSpace($effectiveNode)) {
        $effectiveNode = $script:NodeVersionForLegacyPrisma

        if ($effectiveCli -match '^(\d+)\.' -and [int]$Matches[1] -ge 6) {
            $effectiveNode = $script:NodeVersionForModernPrisma
        }
    }

    return [pscustomobject]@{
        PrismaPython = $prismaClientVersion
        PrismaCli    = $effectiveCli
        PrismaEngine = $effectiveEngine
        NodeVersion  = $effectiveNode
    }
}

function Install-LiteLLMRuntime {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [pscustomobject]$Context,

        [Parameter(Mandatory = $true)]
        [string]$PrismaVersion
    )

    $pythonExe = Get-PortablePythonExe -Context $Context
    $env:PORTABLE_PYTHON_EXE = $pythonExe

    $liteLlmDistInfo = Join-Path $Context.PackagesDir ('litellm-' + $Context.LiteLLMVersion + '.dist-info')
    $prismaDistInfo = Join-Path $Context.PackagesDir ('prisma-' + $PrismaVersion + '.dist-info')
    $pyWin32DistInfo = Join-Path $Context.PackagesDir ('pywin32-' + $Context.PyWin32Version + '.dist-info')

    $alreadyInstalled = (Test-Path -LiteralPath $liteLlmDistInfo) -and
        (Test-Path -LiteralPath $prismaDistInfo) -and
        (Test-Path -LiteralPath $pyWin32DistInfo)

    if ($alreadyInstalled) {
        Write-Host "[OK] LiteLLM $($Context.LiteLLMVersion) + prisma $PrismaVersion + pywin32 $($Context.PyWin32Version) already installed for $($Context.RuntimeSlug)."
    }
    else {
        # uv pip install --target does not uninstall; a version change would layer new files over
        # old ones and skew the package. Start from an empty packages directory.
        if (Test-Path -LiteralPath $Context.PackagesDir) {
            $existing = @(Get-ChildItem -LiteralPath $Context.PackagesDir -Force -ErrorAction SilentlyContinue)
            if ($existing.Count -gt 0) {
                Write-Host "[CLEAN] Clearing packages directory for a clean install ($($Context.RuntimeSlug))."
                $existing | Remove-Item -Recurse -Force
            }
        }

        Write-Host "[INSTALL] LiteLLM $($Context.LiteLLMVersion) + prisma $PrismaVersion + pywin32 $($Context.PyWin32Version)"

        $argumentList = @(
            'pip', 'install',
            '--python', $pythonExe,
            '--target', $Context.PackagesDir,
            '--link-mode', 'copy',
            '--no-python-downloads',
            ("litellm[proxy]==" + $Context.LiteLLMVersion),
            ("prisma==" + $PrismaVersion),
            ("pywin32==" + $Context.PyWin32Version)
        )

        Invoke-NativeCommand -FilePath $Context.UvExe -ArgumentList $argumentList
    }

    Invoke-NativeCommand -FilePath $pythonExe -ArgumentList @('-c', $script:RuntimeImportExpression)
}

function Install-PrismaToolchain {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [pscustomobject]$Context,

        [Parameter(Mandatory = $true)]
        [string]$NodeVersion
    )

    $pythonExe = Get-PortablePythonExe -Context $Context
    $env:PORTABLE_PYTHON_EXE = $pythonExe

    # Stage: partial-state guard. A half-created nodeenv makes prisma-client-python's
    # "cache_dir.exists()" check skip installation and then fail on a missing node binary.
    if (Test-Path -LiteralPath $Context.PrismaNodeenvCacheDir) {
        if (-not (Test-Path -LiteralPath $Context.PrismaNodeExe)) {
            throw [System.InvalidOperationException]::new(
                "Prisma nodeenv exists but is incomplete: $($Context.PrismaNodeenvCacheDir). Rebuild this runtime with -Force.")
        }
    }

    $hasNodeRuntime = Test-Path -LiteralPath $Context.PrismaNodeExe
    $hasPrismaCli = Test-Path -LiteralPath $Context.PrismaCliIndexJs
    $hasQueryEngine = Test-Path -LiteralPath $Context.PrismaQueryEnginePath

    if ($hasNodeRuntime -and $hasPrismaCli -and $hasQueryEngine) {
        Write-Host '[OK] Portable Prisma toolchain already present.'
        return
    }

    # Stage: pinned Node runtime. prisma-client-python passes no --node to nodeenv, so an
    # unconstrained "prisma py fetch" installs the newest Node, whose npm cannot reliably lay
    # down the pinned (older) Prisma CLI. Pre-create the nodeenv with a supported Node release;
    # prisma-client-python then skips nodeenv (it only tests that the directory exists) and
    # reuses this runtime.
    if (-not $hasNodeRuntime) {
        $nodeenvArguments = @('-m', 'nodeenv', '--prebuilt', ('--node=' + $NodeVersion), $Context.PrismaNodeenvCacheDir)

        $env:PRISMA_OFFLINE_MODE = 'false'
        try {
            Invoke-NativeCommand -FilePath $pythonExe -ArgumentList $nodeenvArguments
        }
        finally {
            $env:PRISMA_OFFLINE_MODE = 'true'
        }

        if (-not (Test-Path -LiteralPath $Context.PrismaNodeExe)) {
            throw [System.IO.FileNotFoundException]::new("Pinned Prisma Node runtime was not created: $($Context.PrismaNodeExe)")
        }

        Invoke-NativeCommand -FilePath $Context.PrismaNodeExe -ArgumentList @('--version')
    }

    # Stage: network fetch. Prisma reuses the nodeenv above and installs the pinned CLI + engines.
    $env:PRISMA_OFFLINE_MODE = 'false'
    try {
        $fetchArguments = @('-m', 'prisma', 'py', 'fetch')
        if ($hasPrismaCli -and -not $hasQueryEngine) {
            # Recover a partial fetch whose CLI entrypoint exists but whose engine install failed.
            $fetchArguments += '--force'
        }
        Invoke-NativeCommand -FilePath $pythonExe -ArgumentList $fetchArguments
    }
    finally {
        $env:PRISMA_OFFLINE_MODE = 'true'
    }

    if (-not (Test-Path -LiteralPath $Context.PrismaNodeExe)) {
        throw [System.IO.FileNotFoundException]::new("Portable Prisma Node runtime was not created: $($Context.PrismaNodeExe)")
    }

    if (-not (Test-Path -LiteralPath $Context.PrismaCliIndexJs)) {
        throw [System.IO.FileNotFoundException]::new("Portable Prisma CLI was not created: $($Context.PrismaCliIndexJs)")
    }

    $queryEngineCandidates = @(
        @(
            (Join-Path $Context.PrismaBinaryCacheDir 'node_modules\prisma\query-engine-windows.exe'),
            (Join-Path $Context.PrismaBinaryCacheDir 'node_modules\@prisma\engines\query-engine-windows.exe')
        ) | Where-Object { Test-Path -LiteralPath $_ -PathType Leaf }
    )

    if ($queryEngineCandidates.Count -eq 0) {
        throw [System.IO.FileNotFoundException]::new(
            "Fetched Prisma query engine was not found under '$($Context.PrismaBinaryCacheDir)\node_modules'.")
    }

    $queryEngineSource = $queryEngineCandidates[0]
    Copy-Item -LiteralPath $queryEngineSource -Destination $Context.PrismaQueryEnginePath -Force

    if (-not (Test-Path -LiteralPath $Context.PrismaQueryEnginePath)) {
        throw [System.IO.FileNotFoundException]::new("Portable Prisma query engine was not created: $($Context.PrismaQueryEnginePath)")
    }

    Invoke-NativeCommand -FilePath $Context.PrismaQueryEnginePath -ArgumentList @('--version')
    Invoke-NativeCommand -FilePath $pythonExe -ArgumentList @('-m', 'prisma', '--version')
}

function Write-RuntimeManifest {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [pscustomobject]$Context,

        [Parameter(Mandatory = $true)]
        [pscustomobject]$Pins,

        [Parameter()]
        [string]$PrismaPythonSource = ''
    )

    $manifest = [pscustomobject]@{
        slug               = $Context.RuntimeSlug
        builtUtc           = (Get-Date).ToUniversalTime().ToString('o')
        litellm            = $Context.LiteLLMVersion
        python             = $Context.PythonVersion
        pywin32            = $Context.PyWin32Version
        prismaPython       = $Pins.PrismaPython
        prismaPythonSource = $PrismaPythonSource
        prismaCli          = $Pins.PrismaCli
        prismaEngine       = $Pins.PrismaEngine
        node               = $Pins.NodeVersion
    }

    Write-BoxTextFile -Path $Context.RuntimeManifestPath -Content ($manifest | ConvertTo-Json -Depth 5)
}

function Install-PortablePostgres {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [pscustomobject]$Context
    )

    $postgresExePath = Join-Path $Context.PgBin 'postgres.exe'

    if (Test-Path -LiteralPath $postgresExePath) {
        Write-Host '[OK] Portable PostgreSQL already present.'
        Invoke-NativeCommand -FilePath $postgresExePath -ArgumentList @('--version')
        return
    }

    New-Item -ItemType Directory -Force -Path $Context.TempDir | Out-Null

    $stagingToken = [System.Guid]::NewGuid().ToString('N')
    $archivePath = Join-Path $Context.TempDir "postgresql-$stagingToken.zip"
    $extractPath = Join-Path $Context.TempDir "postgresql-extract-$stagingToken"

    try {
        Save-RemoteFile -Uri $Context.PostgresDownloadUrl -DestinationPath $archivePath
        Expand-DownloadedArchive -ArchivePath $archivePath -DestinationPath $extractPath

        # The EnterpriseDB archive nests the distribution under a top-level "pgsql" folder.
        $directoryFilter = { $_.Directory.Name -ieq 'bin' }
        $postgresExecutable = Find-ArchiveExecutable -SearchRoot $extractPath -FileName 'postgres.exe' -DirectoryFilter $directoryFilter
        $distributionRoot = $postgresExecutable.Directory.Parent.FullName

        Remove-ContainedDirectory -TargetPath $Context.PgHome -ContainerPath $Context.Root
        New-Item -ItemType Directory -Force -Path $Context.PgHome | Out-Null
        Copy-Item -Path (Join-Path $distributionRoot '*') -Destination $Context.PgHome -Recurse -Force
    }
    finally {
        Remove-Item -LiteralPath $archivePath -Force -ErrorAction Ignore
        Remove-Item -LiteralPath $extractPath -Recurse -Force -ErrorAction Ignore
    }

    if (-not (Test-Path -LiteralPath $postgresExePath)) {
        throw [System.IO.FileNotFoundException]::new("postgres.exe was not found after extraction: $postgresExePath")
    }

    Invoke-NativeCommand -FilePath $postgresExePath -ArgumentList @('--version')
}

function Initialize-PostgresCluster {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [pscustomobject]$Context
    )

    $pgVersionMarker = Join-Path $Context.PgData 'PG_VERSION'

    if (Test-Path -LiteralPath $pgVersionMarker) {
        Write-Host '[OK] PostgreSQL data cluster already initialized.'
        return
    }

    New-Item -ItemType Directory -Force -Path $Context.PgData | Out-Null

    $initdbExe = Join-Path $Context.PgBin 'initdb.exe'
    Invoke-NativeCommand -FilePath $initdbExe -ArgumentList @('-D', $Context.PgData, '--encoding=UTF8', '--auth=trust')

    $configLines = @(
        '',
        '# Portable LiteLLM deployment',
        ("listen_addresses = '" + $Context.PostgresHostAddress + "'"),
        ('port = ' + $Context.PostgresPort)
    )

    Add-Content -LiteralPath (Join-Path $Context.PgData 'postgresql.conf') -Value $configLines -Encoding Ascii
    Write-Host '[OK] PostgreSQL data cluster initialized.'
}

function Test-PostgresReady {
    [CmdletBinding()]
    [OutputType([bool])]
    param(
        [Parameter(Mandatory = $true)]
        [pscustomobject]$Context
    )

    $pgIsReadyExe = Join-Path $Context.PgBin 'pg_isready.exe'

    if (-not (Test-Path -LiteralPath $pgIsReadyExe)) {
        return $false
    }

    $exitCode = Invoke-NativeCommand -FilePath $pgIsReadyExe -ArgumentList @(
        '-h', $Context.PostgresHostAddress, '-p', [string]$Context.PostgresPort, '-q') -PassThruExitCode

    return $exitCode -eq 0
}

function Invoke-PgCtl {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [pscustomobject]$Context,

        [Parameter(Mandatory = $true)]
        [string[]]$ArgumentList,

        [Parameter()]
        [int]$TimeoutSeconds = 120
    )

    $pgCtlExe = Join-Path $Context.PgBin 'pg_ctl.exe'

    if (-not (Test-Path -LiteralPath $pgCtlExe)) {
        throw [System.IO.FileNotFoundException]::new("Executable not found: $pgCtlExe")
    }

    # pg_ctl start launches a detached postgres.exe that holds pg_ctl's inherited output handles
    # for the life of the server, so a pumping wait never returns. Redirect streams and wait
    # only on the pg_ctl process object itself.
    $stdoutPath = Join-Path $Context.TempDir ('pg_ctl-out-' + [System.Guid]::NewGuid().ToString('N') + '.log')
    $stderrPath = Join-Path $Context.TempDir ('pg_ctl-err-' + [System.Guid]::NewGuid().ToString('N') + '.log')

    $startParameters = @{
        FilePath               = $pgCtlExe
        ArgumentList           = $ArgumentList
        NoNewWindow            = $true
        PassThru               = $true
        RedirectStandardOutput = $stdoutPath
        RedirectStandardError  = $stderrPath
    }

    try {
        $pgCtlProcess = Start-Process @startParameters
        $null = $pgCtlProcess.Handle
        $exitedInTime = $pgCtlProcess.WaitForExit($TimeoutSeconds * 1000)

        foreach ($outputPath in @($stdoutPath, $stderrPath)) {
            if (Test-Path -LiteralPath $outputPath) {
                $outputText = (Get-Content -LiteralPath $outputPath -Raw)
                if (-not [string]::IsNullOrWhiteSpace($outputText)) {
                    Write-Host $outputText.Trim()
                }
            }
        }

        if (-not $exitedInTime) {
            try {
                $pgCtlProcess.Kill()
            }
            catch {
                Write-Warning 'pg_ctl did not exit and could not be terminated.'
            }

            throw [System.TimeoutException]::new("pg_ctl did not finish within $TimeoutSeconds seconds.")
        }

        if ($pgCtlProcess.ExitCode -ne 0) {
            throw [System.InvalidOperationException]::new("pg_ctl failed with exit code $($pgCtlProcess.ExitCode).")
        }
    }
    finally {
        Remove-Item -LiteralPath $stdoutPath -Force -ErrorAction Ignore
        Remove-Item -LiteralPath $stderrPath -Force -ErrorAction Ignore
    }
}

function Get-PostgresLogTail {
    [CmdletBinding()]
    [OutputType([string])]
    param(
        [Parameter(Mandatory = $true)]
        [pscustomobject]$Context
    )

    if (-not (Test-Path -LiteralPath $Context.PostgresLogPath)) {
        return ''
    }

    $tailLines = @(Get-Content -LiteralPath $Context.PostgresLogPath -Tail 15)
    return "Last PostgreSQL log lines:`n" + ($tailLines -join "`n")
}

function Clear-StalePostgresLock {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [pscustomobject]$Context
    )

    $lockFile = Join-Path $Context.PgData 'postmaster.pid'

    if (-not (Test-Path -LiteralPath $lockFile)) {
        return
    }

    $lockPid = 0
    $firstLine = (Get-Content -LiteralPath $lockFile -TotalCount 1 -ErrorAction SilentlyContinue)

    if (-not [int]::TryParse($firstLine, [ref]$lockPid)) {
        return
    }

    $lockedProcess = Get-Process -Id $lockPid -ErrorAction SilentlyContinue

    if ($null -eq $lockedProcess) {
        Write-Host "[OK] Removing stale postmaster.pid (process $lockPid is not running)."
        Remove-Item -LiteralPath $lockFile -Force -ErrorAction Ignore
    }
}
function Start-PortablePostgres {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [pscustomobject]$Context
    )

    $pgVersionMarker = Join-Path $Context.PgData 'PG_VERSION'

    if (-not (Test-Path -LiteralPath $pgVersionMarker)) {
        throw [System.InvalidOperationException]::new("PostgreSQL data cluster is not initialized: $($Context.PgData)")
    }

    if (Test-PostgresReady -Context $Context) {
        Write-Host "[OK] PostgreSQL is already accepting connections on $($Context.PostgresHostAddress):$($Context.PostgresPort)."
        return
    }

    Clear-StalePostgresLock -Context $Context

    try {
        Invoke-PgCtl -Context $Context -ArgumentList @('start', '-D', $Context.PgData, '-l', $Context.PostgresLogPath, '-w') -TimeoutSeconds 120
    }
    catch {
        $logTail = Get-PostgresLogTail -Context $Context
        $message = $_.Exception.Message
        if ($logTail) {
            $message = $message + "`n" + $logTail
        }
        throw [System.InvalidOperationException]::new($message)
    }

    if (-not (Test-PostgresReady -Context $Context)) {
        $logTail = Get-PostgresLogTail -Context $Context
        $message = 'PostgreSQL did not begin accepting connections after start.'
        if ($logTail) {
            $message = $message + "`n" + $logTail
        }
        throw [System.InvalidOperationException]::new($message)
    }

    Write-Host "[OK] PostgreSQL is accepting connections on $($Context.PostgresHostAddress):$($Context.PostgresPort)."
}

function Stop-PortablePostgres {
    [CmdletBinding()]
    [OutputType([pscustomobject])]
    param(
        [Parameter(Mandatory = $true)]
        [pscustomobject]$Context
    )

    $pgVersionMarker = Join-Path $Context.PgData 'PG_VERSION'
    $pgCtlExe = Join-Path $Context.PgBin 'pg_ctl.exe'

    if (-not (Test-Path -LiteralPath $pgVersionMarker) -or -not (Test-Path -LiteralPath $pgCtlExe)) {
        Write-Host '[OK] No portable PostgreSQL cluster to stop.'
        return [pscustomobject]@{ Action = 'Stop'; PostgresStopped = $false }
    }

    if (-not (Test-PostgresReady -Context $Context)) {
        Write-Host '[OK] PostgreSQL is not running.'
        return [pscustomobject]@{ Action = 'Stop'; PostgresStopped = $false }
    }

    Invoke-PgCtl -Context $Context -ArgumentList @('stop', '-D', $Context.PgData, '-w', '-m', 'fast') -TimeoutSeconds 60
    Write-Host '[OK] PostgreSQL stopped.'
    return [pscustomobject]@{ Action = 'Stop'; PostgresStopped = $true }
}

function Initialize-LiteLLMDatabase {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [pscustomobject]$Context
    )

    if (-not (Test-PostgresReady -Context $Context)) {
        throw [System.InvalidOperationException]::new('PostgreSQL is not accepting connections.')
    }

    # Stage: role and database creation. Guarded SQL, safe to re-run on every deploy and update.
    Write-Host '[DB] Ensuring LiteLLM role and database...'
    $psqlExe = Join-Path $Context.PgBin 'psql.exe'
    Invoke-NativeCommand -FilePath $psqlExe -ArgumentList @(
        '-h', $Context.PostgresHostAddress,
        '-p', [string]$Context.PostgresPort,
        '-d', 'postgres',
        '-v', 'ON_ERROR_STOP=1',
        '-f', $Context.CreateDatabaseSqlPath
    )

    # Stage: schema push + migration ledger. Idempotent; on an update this applies new columns.
    Write-Host '[DB] Applying Prisma schema and migrations...'
    $pythonExe = Get-PortablePythonExe -Context $Context
    $env:PORTABLE_PYTHON_EXE = $pythonExe
    Invoke-NativeCommand -FilePath $pythonExe -ArgumentList @($Context.DatabaseSetupScriptPath)

    # Stage: client-integrity check. "prisma generate" ran during the push above; make sure the
    # generated client and the installed prisma runtime agree before the proxy relies on it.
    Assert-PrismaClientUsable -Context $Context
}

function Assert-PrismaClientUsable {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [pscustomobject]$Context
    )

    $pythonExe = Get-PortablePythonExe -Context $Context

    if (Test-PostgresReady -Context $Context) {
        $expression = $script:PrismaClientConnectExpression
        $checkName = 'connect'
    }
    else {
        $expression = $script:PrismaClientConstructExpression
        $checkName = 'construct (PostgreSQL not running; connect check skipped)'
    }

    $exitCode = Invoke-NativeCommand -FilePath $pythonExe -ArgumentList @('-c', $expression) -PassThruExitCode

    if ($exitCode -ne 0) {
        throw [System.InvalidOperationException]::new(
            "The generated Prisma client is not usable for runtime '$($Context.RuntimeSlug)'. " +
            "This is a prisma-client-python / generated-client version skew (the LiteLLM code path " +
            "expects a different prisma than what was installed). Rebuild with a pinned prisma version, e.g.  " +
            "-Action Update -LiteLLMVersion $($Context.LiteLLMVersion) -Force -PrismaPythonVersion 0.11.0")
    }

    Write-Host "[OK] Generated Prisma client usable ($checkName)."
}

function Test-PortableDeployment {
    [CmdletBinding()]
    [OutputType([pscustomobject])]
    param(
        [Parameter(Mandatory = $true)]
        [pscustomobject]$Context
    )

    $postgresExePath = Join-Path $Context.PgBin 'postgres.exe'
    $pythonExe = Get-PortablePythonExe -Context $Context
    $env:PORTABLE_PYTHON_EXE = $pythonExe

    if (-not (Test-Path -LiteralPath $postgresExePath)) {
        throw [System.IO.FileNotFoundException]::new("Portable PostgreSQL missing: $postgresExePath")
    }

    if (-not (Test-Path -LiteralPath $Context.PrismaNodeExe)) {
        throw [System.IO.FileNotFoundException]::new("Portable Prisma Node runtime missing: $($Context.PrismaNodeExe)")
    }

    if (-not (Test-Path -LiteralPath $Context.PrismaClientPyShimPath)) {
        throw [System.IO.FileNotFoundException]::new("Prisma Python generator shim missing: $($Context.PrismaClientPyShimPath)")
    }

    if (-not (Test-Path -LiteralPath $Context.PrismaQueryEnginePath)) {
        throw [System.IO.FileNotFoundException]::new("Portable Prisma query engine missing: $($Context.PrismaQueryEnginePath)")
    }

    # Stage: import check (also confirms pywin32 / pywintypes loads).
    Invoke-NativeCommand -FilePath $pythonExe -ArgumentList @('-c', $script:RuntimeVerifyExpression)

    # Stage: generated Prisma client is usable (catches a client / runtime version skew).
    Assert-PrismaClientUsable -Context $Context

    # Stage: MCP availability. Reported, never fatal - LiteLLM moves this module path between
    # releases and MCP is optional.
    $mcpLines = @(Get-PythonOutputLines -PythonExe $pythonExe -Expression $script:McpProbeExpression)
    if ($mcpLines.Count -ge 1) {
        Write-Host "[OK] $($mcpLines[0])"
    }
    else {
        Write-Warning 'MCP availability probe did not run (module path may have changed in this LiteLLM version).'
    }

    # Stage: database connectivity as the LiteLLM role.
    $psqlExe = Join-Path $Context.PgBin 'psql.exe'
    Invoke-NativeCommand -FilePath $psqlExe -ArgumentList @(
        '-h', $Context.PostgresHostAddress,
        '-p', [string]$Context.PostgresPort,
        '-U', $Context.PostgresUser,
        '-d', $Context.PostgresDatabase,
        '-v', 'ON_ERROR_STOP=1',
        '-c', 'SELECT 1 AS portable_db_ok;'
    )

    Write-Host "[OK] Runtime '$($Context.RuntimeSlug)' verified."
    return [pscustomobject]@{ Action = 'Verify'; Verified = $true; Root = $Context.Root; Runtime = $Context.RuntimeSlug }
}

function Get-PortableStatus {
    [CmdletBinding()]
    [OutputType([pscustomobject])]
    param(
        [Parameter(Mandatory = $true)]
        [pscustomobject]$Context
    )

    $postgresExePath = Join-Path $Context.PgBin 'postgres.exe'
    $pgVersionMarker = Join-Path $Context.PgData 'PG_VERSION'

    $state = Read-ActiveRuntimeState -Root $Context.Root
    $activeSlug = $(if ($null -ne $state) { $state.active } else { $null })
    $previousSlug = $(if ($null -ne $state) { $state.previous } else { $null })

    $installedRuntimes = @()
    if (Test-Path -LiteralPath $Context.RuntimesDir) {
        $installedRuntimes = @(Get-ChildItem -LiteralPath $Context.RuntimesDir -Directory | Select-Object -ExpandProperty Name | Sort-Object)
    }

    $pythonInstalled = $null -ne (Get-PortablePythonExe -Context $Context -AllowMissing)
    $postgresInstalled = Test-Path -LiteralPath $postgresExePath
    $clusterInitialized = Test-Path -LiteralPath $pgVersionMarker

    $postgresResponding = $false
    if ($postgresInstalled -and $clusterInitialized) {
        $postgresResponding = Test-PostgresReady -Context $Context
    }

    $proxyPortListening = Test-TcpEndpoint -TargetHost $Context.LiteLLMHostAddress -Port $Context.LiteLLMPort -TimeoutMilliseconds 800

    $prismaCliDisplay = $(if ([string]::IsNullOrWhiteSpace($Context.PrismaCliVersion)) { '(client default)' } else { $Context.PrismaCliVersion })

    $status = [pscustomobject]@{
        Action             = 'Status'
        Root               = $Context.Root
        ActiveRuntime      = $activeSlug
        PreviousRuntime    = $previousSlug
        InstalledRuntimes  = $installedRuntimes
        PrismaPython       = $Context.PrismaPythonVersion
        PrismaCli          = $prismaCliDisplay
        PrismaNode         = $Context.PrismaNodeVersion
        PythonInstalled    = $pythonInstalled
        PostgresInstalled  = $postgresInstalled
        ClusterInitialized = $clusterInitialized
        PostgresResponding = $postgresResponding
        ProxyPortListening = $proxyPortListening
        LiteLLMUrl         = "http://$($Context.LiteLLMHostAddress):$($Context.LiteLLMPort)"
    }

    Write-SectionBanner -Title 'Portable LiteLLM status'
    Write-Host ("  Root               : " + $status.Root)
    Write-Host ("  Active runtime     : " + $status.ActiveRuntime)
    Write-Host ("  Previous runtime   : " + $status.PreviousRuntime)
    Write-Host ("  Installed runtimes : " + ($status.InstalledRuntimes -join ', '))
    Write-Host ("  Prisma py/cli/node : " + $status.PrismaPython + " ($($Context.PrismaPythonSource)) / " + $status.PrismaCli + ' / ' + $status.PrismaNode)
    Write-Host ("  PostgreSQL present : " + $status.PostgresInstalled)
    Write-Host ("  Cluster initialized: " + $status.ClusterInitialized)
    Write-Host ("  PostgreSQL ready   : " + $status.PostgresResponding)
    Write-Host ("  Proxy port open    : " + $status.ProxyPortListening)

    return $status
}

function Start-LiteLLMProxy {
    [CmdletBinding()]
    [OutputType([pscustomobject])]
    param(
        [Parameter(Mandatory = $true)]
        [pscustomobject]$Context,

        [Parameter()]
        [string[]]$ProxyArgument
    )

    $pythonExe = Get-PortablePythonExe -Context $Context
    $env:PORTABLE_PYTHON_EXE = $pythonExe

    $pgVersionMarker = Join-Path $Context.PgData 'PG_VERSION'
    if (-not (Test-Path -LiteralPath $pgVersionMarker)) {
        throw [System.InvalidOperationException]::new('PostgreSQL data cluster is not initialized. Run -Action Deploy first.')
    }

    if (-not (Test-Path -LiteralPath $Context.ConfigPath)) {
        throw [System.IO.FileNotFoundException]::new("Config missing: $($Context.ConfigPath). Run -Action Deploy first.")
    }

    if (-not (Test-PostgresReady -Context $Context)) {
        Start-PortablePostgres -Context $Context
    }

    $argumentList = @(
        $Context.LiteLLMBootstrapPath,
        '--config', $Context.ConfigPath,
        '--host', $Context.LiteLLMHostAddress,
        '--port', [string]$Context.LiteLLMPort
    )

    if ($ProxyArgument) {
        $argumentList += $ProxyArgument
    }

    Write-Host "[RUN] LiteLLM proxy ($($Context.RuntimeSlug)) on http://$($Context.LiteLLMHostAddress):$($Context.LiteLLMPort)"
    & $pythonExe @argumentList | Out-Host
    $proxyExitCode = $LASTEXITCODE

    return [pscustomobject]@{ Action = 'Start'; ExitCode = $proxyExitCode; Root = $Context.Root; Runtime = $Context.RuntimeSlug }
}

# ===========================================================================
# Orchestration
# ===========================================================================

function Invoke-RuntimeBuild {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [pscustomobject]$Context
    )

    # Stage: idempotency. A completed manifest means this runtime is already built.
    if (Test-Path -LiteralPath $Context.RuntimeManifestPath) {
        Write-Host "[OK] Runtime '$($Context.RuntimeSlug)' already built."

        $existing = (Get-Content -LiteralPath $Context.RuntimeManifestPath -Raw | ConvertFrom-Json)
        Set-RuntimePrismaEnvironment -CliVersion $existing.prismaCli -EngineVersion $existing.prismaEngine
        Install-PrismaToolchain -Context $Context -NodeVersion $Context.PrismaNodeVersion
        return
    }

    Write-StageBanner -Name "Resolve tested prisma version ($($Context.RuntimeSlug))"
    $prismaPython = Resolve-PrismaPythonVersion -Context $Context
    Write-Host ("[OK] prisma (Python) = {0}  (source: {1})" -f $prismaPython.Version, $prismaPython.Source)

    Write-StageBanner -Name "Install portable Python ($($Context.RuntimeSlug))"
    Install-PortablePython -Context $Context

    Write-StageBanner -Name "Install LiteLLM runtime ($($Context.RuntimeSlug))"
    Install-LiteLLMRuntime -Context $Context -PrismaVersion $prismaPython.Version

    Write-StageBanner -Name "Resolve Prisma toolchain versions ($($Context.RuntimeSlug))"
    $pythonExe = Get-PortablePythonExe -Context $Context
    $pins = Resolve-PrismaPins -Context $Context -PythonExe $pythonExe
    Set-RuntimePrismaEnvironment -CliVersion $pins.PrismaCli -EngineVersion $pins.PrismaEngine
    Write-Host ("[OK] Prisma: client={0} cli={1} engine={2} node={3}" -f `
            "$($pins.PrismaPython)",
        $(if ([string]::IsNullOrWhiteSpace($pins.PrismaCli)) { '(client default)' } else { $pins.PrismaCli }),
        $(if ([string]::IsNullOrWhiteSpace($pins.PrismaEngine)) { '(client default)' } else { $pins.PrismaEngine }),
        $pins.NodeVersion)

    Write-StageBanner -Name "Install Prisma toolchain ($($Context.RuntimeSlug))"
    Install-PrismaToolchain -Context $Context -NodeVersion $pins.NodeVersion

    Write-RuntimeManifest -Context $Context -Pins $pins -PrismaPythonSource $prismaPython.Source
    Write-Host "[OK] Runtime '$($Context.RuntimeSlug)' built."
}

function Set-RuntimePrismaEnvironment {
    [CmdletBinding()]
    param(
        [Parameter()]
        [AllowNull()]
        [AllowEmptyString()]
        [string]$CliVersion,

        [Parameter()]
        [AllowNull()]
        [AllowEmptyString()]
        [string]$EngineVersion
    )

    # Only ever SET these to a real value. An empty PRISMA_VERSION makes prisma-client-python
    # install "prisma@latest"; leaving it unset makes it use its correct internal default.
    if (-not [string]::IsNullOrWhiteSpace($CliVersion)) {
        $env:PRISMA_VERSION = $CliVersion
    }
    if (-not [string]::IsNullOrWhiteSpace($EngineVersion)) {
        $env:PRISMA_EXPECTED_ENGINE_VERSION = $EngineVersion
    }
}

function Remove-StaleRuntimes {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [pscustomobject]$Context,

        [Parameter(Mandatory = $true)]
        [string[]]$Keep
    )

    if (-not (Test-Path -LiteralPath $Context.RuntimesDir)) {
        return
    }

    $keepSet = @{}
    foreach ($slug in $Keep) {
        if (-not [string]::IsNullOrWhiteSpace($slug)) {
            $keepSet[$slug] = $true
        }
    }

    foreach ($directory in @(Get-ChildItem -LiteralPath $Context.RuntimesDir -Directory)) {
        if (-not $keepSet.ContainsKey($directory.Name)) {
            Write-Host "[PRUNE] Removing stale runtime: $($directory.Name)"
            Remove-ContainedDirectory -TargetPath $directory.FullName -ContainerPath $Context.Root
        }
    }
}

function Write-DeployCompleteMarker {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [pscustomobject]$Context
    )

    $manifest = $null
    if (Test-Path -LiteralPath $Context.RuntimeManifestPath) {
        $manifest = (Get-Content -LiteralPath $Context.RuntimeManifestPath -Raw | ConvertFrom-Json)
    }

    $markerContent = [pscustomobject]@{
        completedUtc    = (Get-Date).ToUniversalTime().ToString('o')
        activeRuntime   = $Context.RuntimeSlug
        litellm         = $Context.LiteLLMVersion
        python          = $Context.PythonVersion
        postgresVersion = $Context.PostgresVersion
        targetTriple    = $Context.TargetTriple
        runtimeManifest = $manifest
    } | ConvertTo-Json -Depth 6

    Write-BoxTextFile -Path $Context.DeployCompleteMarkerPath -Content $markerContent
}

function Invoke-PortableDeployment {
    [CmdletBinding()]
    [OutputType([pscustomobject])]
    param(
        [Parameter(Mandatory = $true)]
        [pscustomobject]$Context,

        [Parameter()]
        [switch]$Rebuild,

        [Parameter()]
        [switch]$StartProxyAfterDeploy,

        [Parameter()]
        [string[]]$ProxyArgument
    )

    Write-SectionBanner -Title 'Portable LiteLLM deployment'
    Write-Host ("  Root      : " + $Context.Root)
    Write-Host ("  Target    : " + $Context.TargetTriple)
    Write-Host ("  Runtime   : " + $Context.RuntimeSlug)
    Write-Host ("  LiteLLM   : " + $Context.LiteLLMVersion)
    Write-Host ("  Python    : " + $Context.PythonVersion)
    Write-Host ("  pywin32   : " + $Context.PyWin32Version)
    Write-Host ("  PostgreSQL: " + $Context.PostgresVersion)
    Write-Host ("  Network   : uv timeout=" + $Context.UvHttpTimeout + "s retries=" + $Context.UvHttpRetries + " parallel=" + $Context.UvConcurrentDownloads)

    $pgVersionMarker = Join-Path $Context.PgData 'PG_VERSION'

    if ($Rebuild) {
        Write-Host '[CLEAN] Stopping existing portable PostgreSQL if present...'
        try {
            Stop-PortablePostgres -Context $Context | Out-Null
        }
        catch {
            Write-Warning ("Could not stop PostgreSQL cleanly: " + $_.Exception.Message)
        }

        Write-Host '[CLEAN] Removing existing box directories...'
        foreach ($directoryName in $script:CleanupDirectoryNames) {
            Remove-ContainedDirectory -TargetPath (Join-Path $Context.Root $directoryName) -ContainerPath $Context.Root
        }
        Remove-Item -LiteralPath $Context.UvExe -Force -ErrorAction Ignore
        Remove-Item -LiteralPath $Context.StartCommandPath -Force -ErrorAction Ignore
        Remove-Item -LiteralPath $Context.StopCommandPath -Force -ErrorAction Ignore
    }
    elseif (Test-Path -LiteralPath $Context.DeployCompleteMarkerPath) {
        Write-Host ''
        Write-Host '[RECONVERGE] Completed deployment found. Refreshing helper files and re-verifying (use -Force to rebuild from zero).'
    }
    elseif (Test-Path -LiteralPath $pgVersionMarker) {
        Write-Host ''
        Write-Host '[RESUME] Partial deployment detected. Continuing from where it stopped.'
    }

    Write-StageBanner -Name 'Initialize box layout'
    Initialize-SharedLayout -Context $Context
    Initialize-RuntimeLayout -Context $Context

    Write-StageBanner -Name 'Apply portable environment'
    Set-PortableProcessEnvironment -Context $Context

    Write-StageBanner -Name 'Write portable artifacts'
    Write-PortableArtifact -Context $Context
    Initialize-Config -Context $Context

    Write-StageBanner -Name 'Install uv'
    Install-Uv -Context $Context

    Write-StageBanner -Name 'Install portable PostgreSQL'
    Install-PortablePostgres -Context $Context

    Write-StageBanner -Name "Build runtime $($Context.RuntimeSlug)"
    Invoke-RuntimeBuild -Context $Context
    Set-PortableProcessEnvironment -Context $Context -RuntimeMode

    Write-StageBanner -Name 'Initialize PostgreSQL cluster'
    Initialize-PostgresCluster -Context $Context

    Write-StageBanner -Name 'Start PostgreSQL'
    Start-PortablePostgres -Context $Context

    Write-StageBanner -Name 'Initialize LiteLLM database'
    Initialize-LiteLLMDatabase -Context $Context

    Write-StageBanner -Name 'Verify deployment'
    Test-PortableDeployment -Context $Context | Out-Null

    $previousRuntime = Set-ActiveRuntime -Root $Context.Root -Slug $Context.RuntimeSlug
    Write-DeployCompleteMarker -Context $Context

    Write-SectionBanner -Title 'DEPLOYMENT COMPLETE'
    Write-Host ("  LiteLLM UI : http://$($Context.LiteLLMHostAddress):$($Context.LiteLLMPort)/ui/")
    Write-Host ("  API        : http://$($Context.LiteLLMHostAddress):$($Context.LiteLLMPort)")
    Write-Host ("  Runtime    : " + $Context.RuntimeSlug)
    Write-Host ("  Config     : " + $Context.ConfigPath)
    if (-not [string]::IsNullOrWhiteSpace($previousRuntime)) {
        Write-Host ("  Rollback to: " + $previousRuntime + "   (-Action Rollback)")
    }
    Write-Host ''
    Write-Host 'PostgreSQL is running. Use -Action Start to launch the proxy later.'

    $summary = [pscustomobject]@{
        Action          = 'Deploy'
        Root            = $Context.Root
        Runtime         = $Context.RuntimeSlug
        LiteLLMUrl      = "http://$($Context.LiteLLMHostAddress):$($Context.LiteLLMPort)"
        PostgresRunning = $true
        Verified        = $true
        ProxyStarted    = [bool]$StartProxyAfterDeploy
    }

    if ($StartProxyAfterDeploy) {
        Write-Host ''
        Write-Host 'Starting LiteLLM now...'
        $proxyResult = Start-LiteLLMProxy -Context $Context -ProxyArgument $ProxyArgument
        Add-Member -InputObject $summary -NotePropertyName 'ExitCode' -NotePropertyValue $proxyResult.ExitCode -Force
    }

    return $summary
}

function Invoke-RuntimeUpdate {
    [CmdletBinding()]
    [OutputType([pscustomobject])]
    param(
        [Parameter(Mandatory = $true)]
        [pscustomobject]$Context,

        [Parameter()]
        [switch]$ForceRebuild
    )

    $state = Read-ActiveRuntimeState -Root $Context.Root

    if ($null -eq $state -or [string]::IsNullOrWhiteSpace($state.active)) {
        throw [System.InvalidOperationException]::new('No completed deployment found. Run -Action Deploy first.')
    }

    if ($state.active -eq $Context.RuntimeSlug -and -not $ForceRebuild) {
        Write-Host "[OK] '$($Context.RuntimeSlug)' is already the active runtime. Pass -Force to rebuild it in place."
        return [pscustomobject]@{ Action = 'Update'; Root = $Context.Root; Runtime = $Context.RuntimeSlug; Switched = $false }
    }

    if ($ForceRebuild -and (Test-Path -LiteralPath $Context.RuntimeDir)) {
        Write-Host "[CLEAN] Removing existing runtime directory for rebuild: $($Context.RuntimeSlug)"
        Remove-ContainedDirectory -TargetPath $Context.RuntimeDir -ContainerPath $Context.Root
    }

    Write-SectionBanner -Title 'Portable LiteLLM update'
    Write-Host ("  Root         : " + $Context.Root)
    Write-Host ("  New runtime  : " + $Context.RuntimeSlug + "  (LiteLLM " + $Context.LiteLLMVersion + ")")
    Write-Host ("  Current      : " + $state.active)

    Write-StageBanner -Name 'Apply portable environment'
    Set-PortableProcessEnvironment -Context $Context

    Write-StageBanner -Name 'Refresh portable artifacts'
    Write-PortableArtifact -Context $Context
    Initialize-Config -Context $Context

    Write-StageBanner -Name 'Ensure uv and PostgreSQL'
    Install-Uv -Context $Context
    Install-PortablePostgres -Context $Context

    Write-StageBanner -Name 'Initialize runtime layout'
    Initialize-RuntimeLayout -Context $Context

    Write-StageBanner -Name "Build runtime $($Context.RuntimeSlug)"
    Invoke-RuntimeBuild -Context $Context
    Set-PortableProcessEnvironment -Context $Context -RuntimeMode

    Write-StageBanner -Name 'Ensure PostgreSQL running'
    if (-not (Test-PostgresReady -Context $Context)) {
        Start-PortablePostgres -Context $Context
    }

    Write-StageBanner -Name 'Migrate LiteLLM database'
    Initialize-LiteLLMDatabase -Context $Context

    Write-StageBanner -Name 'Verify new runtime'
    Test-PortableDeployment -Context $Context | Out-Null

    # Stage: switch. Set-ActiveRuntime records the outgoing runtime as "previous" for rollback.
    $previousRuntime = Set-ActiveRuntime -Root $Context.Root -Slug $Context.RuntimeSlug
    Write-DeployCompleteMarker -Context $Context

    $keep = @($Context.RuntimeSlug, $previousRuntime) + @((Read-ActiveRuntimeState -Root $Context.Root).history)
    Remove-StaleRuntimes -Context $Context -Keep $keep

    Write-SectionBanner -Title 'UPDATE COMPLETE'
    Write-Host ("  Active runtime : " + $Context.RuntimeSlug)
    Write-Host ("  Rollback to    : " + $previousRuntime + "   (deploy-litellm-win.ps1 -Action Rollback)")
    Write-Host ''
    Write-Host 'Restart the proxy to pick up the new runtime: -Action Start'

    return [pscustomobject]@{
        Action   = 'Update'
        Root     = $Context.Root
        Runtime  = $Context.RuntimeSlug
        Previous = $previousRuntime
        Switched = $true
        Verified = $true
    }
}

function Invoke-RuntimeRollback {
    [CmdletBinding()]
    [OutputType([pscustomobject])]
    param(
        [Parameter(Mandatory = $true)]
        [string]$TargetTriple
    )

    $root = [System.IO.Path]::GetFullPath($ContainerRoot)
    $state = Read-ActiveRuntimeState -Root $root

    if ($null -eq $state -or [string]::IsNullOrWhiteSpace($state.previous)) {
        throw [System.InvalidOperationException]::new('No previous runtime recorded to roll back to.')
    }

    $previousSlug = [string]$state.previous
    $previousDir = Join-Path (Join-Path $root 'runtimes') $previousSlug

    if (-not (Test-Path -LiteralPath $previousDir)) {
        throw [System.InvalidOperationException]::new("Previous runtime directory is gone: $previousDir")
    }

    $context = New-PortableContext -TargetTriple $TargetTriple -RuntimeSlug $previousSlug

    Write-SectionBanner -Title 'Portable LiteLLM rollback'
    Write-Host ("  From : " + $state.active)
    Write-Host ("  To   : " + $previousSlug)

    Set-PortableProcessEnvironment -Context $context -RuntimeMode

    if (-not (Test-PostgresReady -Context $context)) {
        Start-PortablePostgres -Context $context
    }

    Write-StageBanner -Name 'Verify rollback target'
    Test-PortableDeployment -Context $context | Out-Null

    $rolledBackFrom = Set-ActiveRuntime -Root $root -Slug $previousSlug
    Write-DeployCompleteMarker -Context $context

    Write-SectionBanner -Title 'ROLLBACK COMPLETE'
    Write-Host ("  Active runtime : " + $previousSlug)
    Write-Host '  The database schema was NOT reverted (Prisma migrations are forward-only).'
    Write-Host ''
    Write-Host 'Restart the proxy: -Action Start'

    return [pscustomobject]@{
        Action   = 'Rollback'
        Root     = $root
        Runtime  = $previousSlug
        Previous = $rolledBackFrom
        Switched = $true
    }
}

# ===========================================================================
# Main flow
# ===========================================================================

Assert-WindowsPlatform
$script:TargetTriple = Get-WindowsTargetLabel
$script:OriginalConsoleOutputEncoding = Set-ConsoleOutputUtf8

# Resolve the box directory here (not in the param default): Windows PowerShell 5.1 leaves
# $PSScriptRoot empty during param binding when launched with `powershell.exe -File ...`, as the
# generated start-litellm.cmd does.
if ([string]::IsNullOrWhiteSpace($ContainerRoot)) {
    $ContainerRoot = $PSScriptRoot

    if ([string]::IsNullOrWhiteSpace($ContainerRoot) -and -not [string]::IsNullOrWhiteSpace($PSCommandPath)) {
        $ContainerRoot = Split-Path -Parent $PSCommandPath
    }
}

if ([string]::IsNullOrWhiteSpace($ContainerRoot)) {
    throw [System.ArgumentException]::new('Could not determine the box directory. Pass -ContainerRoot explicitly.')
}

$script:PortableRoot = [System.IO.Path]::GetFullPath($ContainerRoot)

if (-not (Test-Path -LiteralPath $script:PortableRoot)) {
    throw [System.IO.DirectoryNotFoundException]::new("Container root does not exist: $($script:PortableRoot)")
}

$environmentSnapshot = Get-EnvironmentSnapshot
$actionResult = $null
$locationPushed = $false

try {
    Push-Location -LiteralPath $script:PortableRoot
    $locationPushed = $true

    switch ($Action) {
        'Deploy' {
            $slug = Get-RuntimeSlug -LiteLLMVersion $LiteLLMVersion
            $context = New-PortableContext -TargetTriple $script:TargetTriple -RuntimeSlug $slug
            $actionResult = Invoke-PortableDeployment -Context $context -Rebuild:$Force -StartProxyAfterDeploy:$Start -ProxyArgument $LiteLLMArgument
        }
        'Update' {
            $slug = Get-RuntimeSlug -LiteLLMVersion $LiteLLMVersion
            $context = New-PortableContext -TargetTriple $script:TargetTriple -RuntimeSlug $slug
            $actionResult = Invoke-RuntimeUpdate -Context $context -ForceRebuild:$Force
        }
        'Rollback' {
            $actionResult = Invoke-RuntimeRollback -TargetTriple $script:TargetTriple
        }
        'Start' {
            $slug = Get-ActiveRuntimeSlug -Root $script:PortableRoot
            $context = New-PortableContext -TargetTriple $script:TargetTriple -RuntimeSlug $slug
            Set-PortableProcessEnvironment -Context $context -RuntimeMode
            $actionResult = Start-LiteLLMProxy -Context $context -ProxyArgument $LiteLLMArgument
        }
        'Stop' {
            $slug = Get-ActiveRuntimeSlug -Root $script:PortableRoot -AllowMissing
            $context = New-PortableContext -TargetTriple $script:TargetTriple -RuntimeSlug $slug
            Set-PortableProcessEnvironment -Context $context -RuntimeMode
            $actionResult = Stop-PortablePostgres -Context $context
        }
        'Verify' {
            $slug = Get-ActiveRuntimeSlug -Root $script:PortableRoot
            $context = New-PortableContext -TargetTriple $script:TargetTriple -RuntimeSlug $slug
            Set-PortableProcessEnvironment -Context $context -RuntimeMode
            $actionResult = Test-PortableDeployment -Context $context
        }
        'Status' {
            $slug = Get-ActiveRuntimeSlug -Root $script:PortableRoot -AllowMissing
            $context = New-PortableContext -TargetTriple $script:TargetTriple -RuntimeSlug $slug
            Set-PortableProcessEnvironment -Context $context -RuntimeMode
            $actionResult = Get-PortableStatus -Context $context
        }
        default {
            throw [System.ArgumentException]::new("Unsupported action: $Action")
        }
    }
}
finally {
    if ($locationPushed) {
        Pop-Location
    }

    Restore-EnvironmentSnapshot -Snapshot $environmentSnapshot

    if ($null -ne $script:OriginalConsoleOutputEncoding) {
        try {
            [Console]::OutputEncoding = $script:OriginalConsoleOutputEncoding
        }
        catch {
            Write-Verbose "Could not restore the console output encoding: $($_.Exception.Message)"
        }
    }
}

# Defensive: if any stray output slipped into the pipeline, the action summary is the last item.
$summary = $actionResult
if ($actionResult -is [System.Array] -and $actionResult.Count -gt 0) {
    $summary = $actionResult[-1]
}

$summary

if ($null -ne $summary -and $summary.PSObject.Properties['ExitCode']) {
    exit [int]$summary.ExitCode
}

exit 0
