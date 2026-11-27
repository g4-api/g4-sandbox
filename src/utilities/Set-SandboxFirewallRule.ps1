<#
.SYNOPSIS
    Allows the programs of a published G4 sandbox through Windows Firewall, so Windows never prompts while the
    sandbox runs.

.DESCRIPTION
    Windows Firewall asks the signed-in user whether to allow a program the first time that program listens on a
    network port and no rule covers it. Every G4 sandbox installs into its own versioned folder, so without rules
    every release shows these prompts again, and an unanswered prompt covers the screen that UI automation drives.

    The script resolves the sandbox programs that open ports (the .NET host that runs the Hub, the recorders and the
    drivers, the driver and tool executables, Java for the grid, Node.js for Appium, Chrome, ChromeDriver, VS Code,
    the LiteLLM Python runtime, Gitea and OpenCode). It then:

    1. removes the rules of sandbox folders that no longer exist beside this sandbox;
    2. removes the rules that already cover programs inside this sandbox, including rules created by answering a
       prompt, and the rules of an earlier run for this folder;
    3. adds one inbound allow rule per program, for every network profile, in the rule group
       'G4 Sandbox (<sandbox folder name>)'.

    Rules are bound to exact program paths, because Windows Firewall does not support wildcards in program paths.
    Changing firewall rules requires administrator rights. When the script runs without them, it starts itself once
    more elevated, which shows one User Account Control consent, waits for that run and returns its summary.

    The script runs in Windows PowerShell 5.1 and in PowerShell 7 on Windows. Running it again converges on the same
    rules.

.PARAMETER SandboxDirectory
    The published sandbox folder, for example 'C:\g4-sandbox\g4-sandbox-v2026.11.27.93'. The folder must exist.
    Its parent folder is scanned for the rules of removed 'g4-sandbox-*' sibling folders.

.PARAMETER StageDirectory
    Optional staging folder of the publish run ('<output>-bootstrap\a'). The publish starts Gitea from this folder
    to configure it, so the Gitea programs there get rules in the group 'G4 Sandbox (staging)' as well. That group
    is replaced on every run and is never treated as stale.

.PARAMETER ResultPath
    Optional file that receives the summary as JSON. The non-elevated run passes it to the elevated run to read the
    summary back; callers normally omit it.

.EXAMPLE
    .\Set-SandboxFirewallRule.ps1 -SandboxDirectory 'C:\g4-sandbox\g4-sandbox-v2026.11.27.93'

    Replaces the firewall rules of that sandbox and removes the rules of sandbox folders that no longer exist.

.EXAMPLE
    .\Set-SandboxFirewallRule.ps1 -SandboxDirectory 'C:\g4-sandbox\g4-sandbox-v2026.11.27.93' -WhatIf

    Lists the rules the script would remove and add without changing the firewall.

.INPUTS
    None.

.OUTPUTS
    System.Management.Automation.PSCustomObject. A summary with the rule group, the added programs and the number of
    removed rules.

.NOTES
    Side effects: changes the Windows Firewall rules of the local computer. Only rules whose program is inside this
    sandbox, inside a removed sibling 'g4-sandbox-*' folder, or inside the given staging folder are removed.
#>
#Requires -Version 5.1
[CmdletBinding(PositionalBinding = $false, SupportsShouldProcess = $true)]
param(
    [Parameter(Mandatory = $true)]
    [ValidateNotNullOrEmpty()]
    [string]$SandboxDirectory,

    [Parameter()]
    [ValidateNotNullOrEmpty()]
    [string]$StageDirectory,

    [Parameter()]
    [ValidateNotNullOrEmpty()]
    [string]$ResultPath
)

Set-StrictMode -Version 3.0
$ErrorActionPreference = 'Stop'

# Programs at fixed places inside a sandbox that open network ports, relative to the sandbox folder.
$fixedProgramPaths = @(
    'runtime\dotnet\dotnet.exe',
    'runtime\jdk\bin\java.exe',
    'runtime\nodejs\node.exe',
    'browsers\chrome\chrome.exe',
    'bot-utilities\vs-code\Code.exe',
    'gitea\gitea.exe',
    'gitea\runner\gitea-runner.exe'
)

# Folders whose tool folders each hold their own executable (drivers, recorders, inspectors, Test Wright).
$toolRootPaths = @(
    'drivers',
    'bot-utilities'
)

# Tool folders without a network listener; their executables get no rule.
$excludedToolFolderNames = @(
    'powershell',
    'python-installer',
    'scripts',
    'vs-code',
    'vsixs',
    'windows-terminal'
)

# Helper executables that .NET publishes beside an application and that never listen.
$excludedExecutableNames = @(
    'createdump.exe',
    'testhost.exe'
)

# The Gitea programs that the publish starts from its staging folder.
$stageProgramPaths = @(
    'gitea\gitea.exe',
    'gitea\runner\gitea-runner.exe'
)

# The rule group of the staging programs; it is replaced on every run.
$stageGroupName = 'G4 Sandbox (staging)'

function Test-Administrator {
    [CmdletBinding()]
    [OutputType([bool])]
    param()

    # Firewall rules belong to the computer, so only an elevated administrator token can change them.
    $identity = [System.Security.Principal.WindowsIdentity]::GetCurrent()
    $principal = New-Object -TypeName System.Security.Principal.WindowsPrincipal -ArgumentList $identity

    return $principal.IsInRole([System.Security.Principal.WindowsBuiltInRole]::Administrator)
}

function Test-PathDescendant {
    [CmdletBinding()]
    [OutputType([bool])]
    param(
        [Parameter(Mandatory = $true)]
        [string]$Path,

        [Parameter(Mandatory = $true)]
        [string]$RootPath
    )

    # Compare with a trailing separator so a sibling such as 'g4-sandbox-v1.10' never matches 'g4-sandbox-v1.1'.
    $rootPrefix = $RootPath.TrimEnd('\') + '\'

    return $Path.StartsWith($rootPrefix, [System.StringComparison]::OrdinalIgnoreCase)
}

function Test-RemovableProgram {
    [CmdletBinding()]
    [OutputType([bool])]
    param(
        [Parameter()]
        [string]$Program,

        [Parameter(Mandatory = $true)]
        [string]$SandboxRoot,

        [Parameter()]
        [string]$StageRoot
    )

    # Skip rules without a program path, such as port or service rules, which no sandbox owns.
    $isProgramPath = -not [string]::IsNullOrEmpty($Program) -and $Program -ne 'Any' -and [System.IO.Path]::IsPathRooted($Program)

    if (-not $isProgramPath) {
        return $false
    }

    # Replace the rules of this sandbox, whether an earlier run or an answered prompt created them.
    if (Test-PathDescendant -Path $Program -RootPath $SandboxRoot) {
        return $true
    }

    # Replace the staging rules of an earlier publish run.
    $isInStage = -not [string]::IsNullOrEmpty($StageRoot) -and (Test-PathDescendant -Path $Program -RootPath $StageRoot)

    if ($isInStage) {
        return $true
    }

    # Remove the rules of sibling 'g4-sandbox-*' folders that were deleted, because their programs can never run
    # again; a sibling that still exists keeps its rules.
    $parentRoot = Split-Path -Path $SandboxRoot -Parent

    if (-not (Test-PathDescendant -Path $Program -RootPath $parentRoot)) {
        return $false
    }

    $relativePath = $Program.Substring($parentRoot.TrimEnd('\').Length + 1)
    $siblingName = $relativePath.Split('\')[0]
    $siblingPath = Join-Path -Path $parentRoot -ChildPath $siblingName
    $isSandboxSibling = $siblingName -like 'g4-sandbox-*'

    return ($isSandboxSibling -and -not (Test-Path -LiteralPath $siblingPath -PathType Container))
}

function Get-SandboxProgram {
    [CmdletBinding()]
    [OutputType([string[]])]
    param(
        [Parameter(Mandatory = $true)]
        [string]$RootPath
    )

    $programs = New-Object -TypeName System.Collections.Generic.List[string]

    # Add the fixed programs that this sandbox ships; a sandbox without a subsystem simply lacks its program.
    foreach ($relativePath in $fixedProgramPaths) {
        $programPath = Join-Path -Path $RootPath -ChildPath $relativePath

        if (Test-Path -LiteralPath $programPath -PathType Leaf) {
            $programs.Add($programPath)
        }
    }

    # Add the executable at the top of every tool folder, because each driver, recorder and inspector is
    # published as its own application and its file name changes with the tool, not with the sandbox.
    foreach ($toolRootPath in $toolRootPaths) {
        $toolRoot = Join-Path -Path $RootPath -ChildPath $toolRootPath

        if (-not (Test-Path -LiteralPath $toolRoot -PathType Container)) {
            continue
        }

        $toolFolders = @(Get-ChildItem -LiteralPath $toolRoot -Directory)

        foreach ($toolFolder in $toolFolders) {
            if ($excludedToolFolderNames -contains $toolFolder.Name) {
                continue
            }

            $executables = @(Get-ChildItem -LiteralPath $toolFolder.FullName -Filter '*.exe' -File)

            foreach ($executable in $executables) {
                if ($excludedExecutableNames -notcontains $executable.Name) {
                    $programs.Add($executable.FullName)
                }
            }
        }
    }

    # Add the LiteLLM Python runtime; its folder names carry the LiteLLM and Python versions, so it is found
    # rather than listed.
    $liteLLMRuntimeRoot = Join-Path -Path $RootPath -ChildPath 'litellm\runtimes'

    if (Test-Path -LiteralPath $liteLLMRuntimeRoot -PathType Container) {
        $pythonExecutables = @(Get-ChildItem -LiteralPath $liteLLMRuntimeRoot -Filter 'python.exe' -File -Recurse -Depth 3)

        foreach ($pythonExecutable in $pythonExecutables) {
            $programs.Add($pythonExecutable.FullName)
        }
    }

    # Add OpenCode, which the agent partitions box under their own folders.
    $agentRoot = Join-Path -Path $RootPath -ChildPath 'ai-agents'

    if (Test-Path -LiteralPath $agentRoot -PathType Container) {
        $openCodeExecutables = @(Get-ChildItem -LiteralPath $agentRoot -Filter 'opencode.exe' -File -Recurse)

        foreach ($openCodeExecutable in $openCodeExecutables) {
            $programs.Add($openCodeExecutable.FullName)
        }
    }

    return [string[]]@($programs | Sort-Object -Unique)
}

function Remove-SandboxFirewallRule {
    [CmdletBinding(SupportsShouldProcess = $true)]
    [OutputType([int])]
    param(
        [Parameter(Mandatory = $true)]
        [string]$SandboxRoot,

        [Parameter(Mandatory = $true)]
        [string]$GroupName,

        [Parameter()]
        [string]$StageRoot
    )

    # Read every program filter of the local rules once; the filters carry the program path that each rule is bound
    # to. The persistent store holds both prompt-created and scripted rules, and no policy-managed rule.
    $applicationFilters = @(Get-NetFirewallApplicationFilter -PolicyStore PersistentStore)
    $staleFilters = New-Object -TypeName System.Collections.Generic.List[object]

    # Select the filters whose program this run replaces or whose sandbox folder is gone.
    foreach ($applicationFilter in $applicationFilters) {
        $isRemovable = Test-RemovableProgram -Program ([string]$applicationFilter.Program) -SandboxRoot $SandboxRoot -StageRoot $StageRoot

        if ($isRemovable) {
            $staleFilters.Add($applicationFilter)
        }
    }

    # Resolve the rules behind the selected filters and add the group rules, which a rule without a program filter
    # match would otherwise keep.
    $rules = New-Object -TypeName System.Collections.Generic.List[object]

    foreach ($staleFilter in $staleFilters) {
        foreach ($filterRule in @($staleFilter | Get-NetFirewallRule)) {
            $rules.Add($filterRule)
        }
    }

    $groupRules = @(Get-NetFirewallRule -PolicyStore PersistentStore | Where-Object { $_.Group -eq $GroupName -or $_.Group -eq $stageGroupName })

    foreach ($groupRule in $groupRules) {
        $rules.Add($groupRule)
    }

    $uniqueRules = @($rules | Sort-Object -Property Name -Unique)

    # Remove the rules from the persistent store, where both prompt-created and scripted rules live.
    foreach ($rule in $uniqueRules) {
        if ($PSCmdlet.ShouldProcess($rule.DisplayName, 'Remove firewall rule')) {
            Remove-NetFirewallRule -Name $rule.Name -PolicyStore PersistentStore
        }
    }

    return $uniqueRules.Count
}

function Add-SandboxFirewallRule {
    [CmdletBinding(SupportsShouldProcess = $true)]
    [OutputType([string[]])]
    param(
        [Parameter(Mandatory = $true)]
        [string]$RootPath,

        [Parameter(Mandatory = $true)]
        [string[]]$ProgramPath,

        [Parameter(Mandatory = $true)]
        [string]$GroupName
    )

    $addedPrograms = New-Object -TypeName System.Collections.Generic.List[string]

    # Add one inbound allow rule per program for every profile and protocol, so no network type and no protocol
    # leaves a gap that Windows would fill with a prompt.
    foreach ($program in $ProgramPath) {
        $relativePath = $program.Substring($RootPath.TrimEnd('\').Length + 1)
        $displayName = '{0} - {1}' -f $GroupName, $relativePath

        $ruleParameters = @{
            Action = 'Allow'
            Description = 'Allows a G4 sandbox program to accept connections, so Windows does not prompt while G4 runs.'
            Direction = 'Inbound'
            DisplayName = $displayName
            Group = $GroupName
            Profile = 'Any'
            Program = $program
        }

        if ($PSCmdlet.ShouldProcess($displayName, 'Add firewall rule')) {
            New-NetFirewallRule @ruleParameters | Out-Null
            $addedPrograms.Add($relativePath)
        }
    }

    return [string[]]$addedPrograms.ToArray()
}

function Invoke-ElevatedRun {
    [CmdletBinding()]
    [OutputType([object])]
    param(
        [Parameter(Mandatory = $true)]
        [string]$SandboxRoot,

        [Parameter()]
        [string]$StageRoot
    )

    # Collect the elevated run's summary in a file inside the sandbox, because an elevated process cannot write to
    # this console.
    $summaryPath = Join-Path -Path $SandboxRoot -ChildPath ('.firewall-summary-{0}.json' -f [guid]::NewGuid().ToString('N'))
    $argumentsList = New-Object -TypeName System.Collections.Generic.List[string]
    $argumentsList.AddRange([string[]]@(
        '-NoProfile',
        '-ExecutionPolicy', 'Bypass',
        '-File', ('"{0}"' -f $PSCommandPath),
        '-SandboxDirectory', ('"{0}"' -f $SandboxRoot),
        '-ResultPath', ('"{0}"' -f $summaryPath)
    ))

    if (-not [string]::IsNullOrEmpty($StageRoot)) {
        $argumentsList.AddRange([string[]]@('-StageDirectory', ('"{0}"' -f $StageRoot)))
    }

    # Carry a dry run over to the elevated run, so -WhatIf never changes the firewall.
    if ($WhatIfPreference) {
        $argumentsList.Add('-WhatIf')
    }

    try {
        # Start the same script elevated; Windows shows one User Account Control consent for it.
        $processParameters = @{
            ArgumentList = $argumentsList.ToArray()
            FilePath = 'powershell.exe'
            PassThru = $true
            Verb = 'RunAs'
            Wait = $true
            WindowStyle = 'Hidden'
        }

        $process = Start-Process @processParameters

        # Fail with the elevated run's exit code; its summary file is missing when it failed before writing it.
        if ($process.ExitCode -ne 0 -or -not (Test-Path -LiteralPath $summaryPath -PathType Leaf)) {
            $message = "The elevated firewall run failed with exit code $($process.ExitCode)."
            throw [System.InvalidOperationException]::new($message)
        }

        return (Get-Content -LiteralPath $summaryPath -Raw | ConvertFrom-Json)
    }
    finally {
        # Remove the summary file, which belongs only to this run.
        if (Test-Path -LiteralPath $summaryPath -PathType Leaf) {
            Remove-Item -LiteralPath $summaryPath -Force
        }
    }
}

# Resolve the folders once, so every comparison below uses canonical full paths.
$sandboxRoot = [System.IO.Path]::GetFullPath($SandboxDirectory).TrimEnd('\')

if (-not (Test-Path -LiteralPath $sandboxRoot -PathType Container)) {
    $message = "The sandbox folder '$sandboxRoot' does not exist."
    throw [System.IO.DirectoryNotFoundException]::new($message)
}

$stageRoot = $null

if (-not [string]::IsNullOrEmpty($StageDirectory)) {
    $stageRoot = [System.IO.Path]::GetFullPath($StageDirectory).TrimEnd('\')
}

# Hand the work to an elevated run when this one cannot change firewall rules, and return its summary.
if (-not (Test-Administrator)) {
    return (Invoke-ElevatedRun -SandboxRoot $sandboxRoot -StageRoot $stageRoot)
}

$groupName = 'G4 Sandbox ({0})' -f (Split-Path -Path $sandboxRoot -Leaf)

# Remove the rules this run replaces and the rules of removed sandbox folders before adding the new set.
$removedCount = Remove-SandboxFirewallRule -SandboxRoot $sandboxRoot -GroupName $groupName -StageRoot $stageRoot

# Add the rules for the programs this sandbox ships.
$sandboxPrograms = Get-SandboxProgram -RootPath $sandboxRoot
$addedPrograms = @()

if ($sandboxPrograms.Count -gt 0) {
    $addedPrograms = @(Add-SandboxFirewallRule -RootPath $sandboxRoot -ProgramPath $sandboxPrograms -GroupName $groupName)
}

# Add the staging Gitea rules by path; the staging files may already be gone, and a rule does not need its file.
$addedStagePrograms = @()

if ($null -ne $stageRoot) {
    $stagePrograms = @($stageProgramPaths | ForEach-Object { Join-Path -Path $stageRoot -ChildPath $_ })
    $addedStagePrograms = @(Add-SandboxFirewallRule -RootPath $stageRoot -ProgramPath $stagePrograms -GroupName $stageGroupName)
}

# Return the summary, and write it for the non-elevated run that started this one.
$summary = [pscustomobject]@{
    Group = $groupName
    AddedPrograms = $addedPrograms
    AddedStagePrograms = $addedStagePrograms
    RemovedRuleCount = $removedCount
}

if (-not [string]::IsNullOrEmpty($ResultPath)) {
    $summary | ConvertTo-Json -Depth 3 | Set-Content -LiteralPath $ResultPath -Encoding UTF8
}

return $summary
