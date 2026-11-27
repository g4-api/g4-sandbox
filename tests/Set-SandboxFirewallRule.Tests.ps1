# Pester tests for src/utilities/Set-SandboxFirewallRule.ps1. They run in Windows PowerShell 5.1 with Pester 3.4 and
# later: assertions throw, because the legacy and the current Should syntax have no form in common.
# The script's main flow changes the computer's firewall and has a mandatory parameter, so the tests load only its
# data and functions through the parser and never run the main flow.

Describe 'Set-SandboxFirewallRule' {
    BeforeAll {
        # Arrange: load the script's data and helper functions, which sit before the main flow, into this scope.
        $scriptPath = Join-Path -Path $PSScriptRoot -ChildPath '..\src\utilities\Set-SandboxFirewallRule.ps1'
        $parseErrors = $null
        $scriptAst = [System.Management.Automation.Language.Parser]::ParseFile((Resolve-Path -LiteralPath $scriptPath).Path, [ref]$null, [ref]$parseErrors)

        if (@($parseErrors).Count -gt 0) {
            throw "The firewall script does not parse: $($parseErrors[0].Message)"
        }

        $statements = @($scriptAst.EndBlock.Statements)
        $lastFunction = @($statements | Where-Object { $_ -is [System.Management.Automation.Language.FunctionDefinitionAst] })[-1]
        $definitions = @($statements | Where-Object {
            $isBeforeMainFlow = $_.Extent.EndOffset -le $lastFunction.Extent.EndOffset
            $isDefinition = $_ -is [System.Management.Automation.Language.FunctionDefinitionAst] -or $_ -is [System.Management.Automation.Language.AssignmentStatementAst]
            $isBeforeMainFlow -and $isDefinition -and $_.Extent.Text -notlike '$ErrorActionPreference*'
        })

        foreach ($definition in $definitions) {
            . ([scriptblock]::Create($definition.Extent.Text))
        }

        # Fails the current test with a message that names the expected and the actual value.
        function Assert-Equal {
            param($Expected, $Actual, [string]$Because)

            if ($Expected -ne $Actual) {
                throw "Expected '$Expected' but found '$Actual': $Because"
            }
        }

        # Fails the current test when two string sets differ, ignoring order.
        function Assert-SameSet {
            param([string[]]$Expected, [string[]]$Actual)

            $difference = @(Compare-Object -ReferenceObject @($Expected) -DifferenceObject @($Actual))

            if ($difference.Count -gt 0) {
                $differenceText = ($difference | ForEach-Object { '{0} {1}' -f $_.SideIndicator, $_.InputObject }) -join '; '
                throw "The sets differ: $differenceText"
            }
        }
    }

    Context 'Test-PathDescendant' {
        It 'accepts a program inside the root written with different letter case' {
            # Act: compare a path below the root with the root in another letter case.
            $isDescendant = Test-PathDescendant -Path 'C:\G4-SANDBOX\g4-sandbox-v1\runtime\dotnet\dotnet.exe' -RootPath 'c:\g4-sandbox\G4-SANDBOX-V1'

            # Assert: Windows paths are case-insensitive, so the program belongs to the root.
            Assert-Equal -Expected $true -Actual $isDescendant -Because 'Windows compares paths case-insensitively'
        }

        It 'rejects a sibling folder whose name starts with the root folder name' {
            # Act: compare a path in 'g4-sandbox-v1.10' with the root 'g4-sandbox-v1.1'.
            $isDescendant = Test-PathDescendant -Path 'C:\g4-sandbox\g4-sandbox-v1.10\runtime\dotnet\dotnet.exe' -RootPath 'C:\g4-sandbox\g4-sandbox-v1.1'

            # Assert: the separator boundary keeps a similarly named sibling outside the root.
            Assert-Equal -Expected $false -Actual $isDescendant -Because 'a shared name prefix is not containment'
        }
    }

    Context 'Test-RemovableProgram' {
        BeforeAll {
            # Arrange: an output folder with the current sandbox, one older sandbox that still exists and a staging
            # folder beside it; 'g4-sandbox-v0' and 'other-tool' do not exist.
            $outputRoot = Join-Path -Path $TestDrive -ChildPath 'output'
            $sandboxRoot = Join-Path -Path $outputRoot -ChildPath 'g4-sandbox-v2'
            $existingSiblingRoot = Join-Path -Path $outputRoot -ChildPath 'g4-sandbox-v1'
            $stageRoot = Join-Path -Path $TestDrive -ChildPath 'output-bootstrap\a'

            foreach ($folder in $sandboxRoot, $existingSiblingRoot, $stageRoot) {
                New-Item -ItemType Directory -Path $folder -Force | Out-Null
            }
        }

        It 'removes a rule for a program inside the current sandbox' {
            # Act and Assert: a prompt-created or earlier rule of this sandbox is replaced.
            $isRemovable = Test-RemovableProgram -Program (Join-Path $sandboxRoot 'runtime\dotnet\dotnet.exe') -SandboxRoot $sandboxRoot -StageRoot $stageRoot
            Assert-Equal -Expected $true -Actual $isRemovable -Because 'rules of the current sandbox are replaced'
        }

        It 'removes a rule for a program inside the staging folder' {
            # Act and Assert: the staging Gitea rules of an earlier publish are replaced.
            $isRemovable = Test-RemovableProgram -Program (Join-Path $stageRoot 'gitea\gitea.exe') -SandboxRoot $sandboxRoot -StageRoot $stageRoot
            Assert-Equal -Expected $true -Actual $isRemovable -Because 'staging rules are replaced'
        }

        It 'removes a rule for a program of a deleted g4-sandbox folder' {
            # Act and Assert: the program of a removed sandbox version can never run again.
            $isRemovable = Test-RemovableProgram -Program (Join-Path $outputRoot 'g4-sandbox-v0\runtime\dotnet\dotnet.exe') -SandboxRoot $sandboxRoot -StageRoot $stageRoot
            Assert-Equal -Expected $true -Actual $isRemovable -Because 'the sandbox folder no longer exists'
        }

        It 'keeps a rule for a program of a g4-sandbox folder that still exists' {
            # Act and Assert: another installed sandbox keeps its rules.
            $isRemovable = Test-RemovableProgram -Program (Join-Path $existingSiblingRoot 'runtime\dotnet\dotnet.exe') -SandboxRoot $sandboxRoot -StageRoot $stageRoot
            Assert-Equal -Expected $false -Actual $isRemovable -Because 'the older sandbox is still installed'
        }

        It 'keeps a rule for a deleted folder that is not a g4-sandbox folder' {
            # Act and Assert: folders the sandbox does not own are never cleaned up.
            $isRemovable = Test-RemovableProgram -Program (Join-Path $outputRoot 'other-tool\tool.exe') -SandboxRoot $sandboxRoot -StageRoot $stageRoot
            Assert-Equal -Expected $false -Actual $isRemovable -Because 'only g4-sandbox-* siblings are owned'
        }

        It 'keeps rules without a program path' {
            # Act: test the program values of port, service and system rules.
            $results = @('Any', '', 'System' | ForEach-Object { Test-RemovableProgram -Program $_ -SandboxRoot $sandboxRoot -StageRoot $stageRoot })

            # Assert: none of them belongs to a sandbox.
            Assert-SameSet -Expected @('False', 'False', 'False') -Actual @($results | ForEach-Object { "$_" })
        }
    }

    Context 'Get-SandboxProgram' {
        It 'finds the listening programs and skips helpers, excluded tool folders and missing subsystems' {
            # Arrange: a sandbox without Gitea, Chrome and VS Code, with tools, helpers, LiteLLM Python and OpenCode.
            $sandboxRoot = Join-Path -Path $TestDrive -ChildPath 'g4-sandbox-v3'
            $files = @(
                'runtime\dotnet\dotnet.exe',
                'runtime\jdk\bin\java.exe',
                'runtime\nodejs\node.exe',
                'drivers\uia-driver-server\Uia.DriverServer.exe',
                'drivers\uia-driver-server\testhost.exe',
                'drivers\chrome\chromedriver.exe',
                'bot-utilities\uia-recorder-win-x64\G4.Recorders.Uia.exe',
                'bot-utilities\ocr-inspector-win-x64\createdump.exe',
                'bot-utilities\powershell\pwsh.exe',
                'litellm\runtimes\litellm-1.0.0\python\cpython-3.13.0\python.exe',
                'litellm\runtimes\litellm-1.0.0\packages\bin\litellm.exe',
                'ai-agents\partitions\g4-explorer\opencode\runtime\bin\opencode.exe'
            )

            foreach ($file in $files) {
                $filePath = Join-Path -Path $sandboxRoot -ChildPath $file
                New-Item -ItemType Directory -Path (Split-Path -Path $filePath -Parent) -Force | Out-Null
                New-Item -ItemType File -Path $filePath -Force | Out-Null
            }

            # Act: resolve the programs of the fixture sandbox.
            $programs = @(Get-SandboxProgram -RootPath $sandboxRoot | ForEach-Object { $_.Substring($sandboxRoot.Length + 1) })

            # Assert: exactly the listening programs are found; helpers, pwsh, package shims and absent subsystems
            # get no rule.
            $expected = @(
                'runtime\dotnet\dotnet.exe',
                'runtime\jdk\bin\java.exe',
                'runtime\nodejs\node.exe',
                'drivers\uia-driver-server\Uia.DriverServer.exe',
                'drivers\chrome\chromedriver.exe',
                'bot-utilities\uia-recorder-win-x64\G4.Recorders.Uia.exe',
                'litellm\runtimes\litellm-1.0.0\python\cpython-3.13.0\python.exe',
                'ai-agents\partitions\g4-explorer\opencode\runtime\bin\opencode.exe'
            )
            Assert-SameSet -Expected $expected -Actual $programs
        }
    }
}
