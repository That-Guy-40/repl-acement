<#
    Pester tests for New-RemoteApp.ps1.

    These focus on the pure, OS-independent core (New-RdpContent and field
    derivation) so they run anywhere PowerShell + Pester are available,
    including the Linux CI box. The mstsc launch, SSH tunnel, and registry
    paths are integration concerns and are not exercised here.

    Run with:  Invoke-Pester -Path ./New-RemoteApp.Tests.ps1
#>

BeforeAll {
    $script:ScriptPath = Join-Path $PSScriptRoot 'New-RemoteApp.ps1'

    # Dot-source just the helper functions without executing the param/main
    # body. We do this by extracting the function definitions via the parser,
    # which keeps the test independent of the script's parameter sets.
    $tokens = $null; $errors = $null
    $ast = [System.Management.Automation.Language.Parser]::ParseFile(
        $script:ScriptPath, [ref]$tokens, [ref]$errors)
    $funcs = $ast.FindAll(
        { param($n) $n -is [System.Management.Automation.Language.FunctionDefinitionAst] },
        $false)
    foreach ($f in $funcs) {
        . ([scriptblock]::Create($f.Extent.Text))
    }
}

Describe 'New-RdpContent' {
    It 'produces all required RemoteApp fields' {
        $rdp = New-RdpContent -Address 'host:3389' -AppName 'Notepad' `
            -Program 'C:\Windows\System32\notepad.exe'

        $rdp | Should -Match 'full address:s:host:3389'
        $rdp | Should -Match 'remoteapplicationmode:i:1'
        $rdp | Should -Match 'remoteapplicationname:s:Notepad'
        $rdp | Should -Match ([regex]::Escape('remoteapplicationprogram:s:C:\Windows\System32\notepad.exe'))
        $rdp | Should -Match 'remoteapplicationcmdline:s:'
        $rdp | Should -Match 'disableremoteappcapscheck:i:1'
        $rdp | Should -Match 'prompt for credentials on client:i:1'
    }

    It 'uses CRLF line endings' {
        $rdp = New-RdpContent -Address 'h:3389' -AppName 'A' -Program 'p.exe'
        $rdp | Should -Match "`r`n"
        # No bare LF that isn't preceded by CR.
        ($rdp -split "`r`n" -join '') | Should -Not -Match "`n"
    }

    It 'embeds the command line when supplied' {
        $rdp = New-RdpContent -Address 'h:3389' -AppName 'A' -Program 'p.exe' -CmdLine '--flag value'
        $rdp | Should -Match ([regex]::Escape('remoteapplicationcmdline:s:--flag value'))
    }

    It 'reflects the address verbatim (tunnel case)' {
        $rdp = New-RdpContent -Address 'localhost:13389' -AppName 'A' -Program 'p.exe'
        $rdp | Should -Match 'full address:s:localhost:13389'
    }

    It 'handles program paths containing spaces' {
        $prog = 'C:\Program Files\My App\app.exe'
        $rdp = New-RdpContent -Address 'h:3389' -AppName 'App' -Program $prog
        $rdp | Should -Match ([regex]::Escape("remoteapplicationprogram:s:$prog"))
    }
}

Describe 'Get-AppNameFromProgram' {
    It 'derives the base name from a Windows program path' {
        Get-AppNameFromProgram -Program 'C:\Windows\System32\notepad.exe' | Should -Be 'notepad'
    }

    It 'derives a name from a path with spaces' {
        Get-AppNameFromProgram -Program 'C:\Program Files\My App\app.exe' | Should -Be 'app'
    }

    It 'handles forward-slash paths too' {
        Get-AppNameFromProgram -Program '/opt/tools/foo.exe' | Should -Be 'foo'
    }

    It 'returns the leaf when there is no extension' {
        Get-AppNameFromProgram -Program 'C:\bin\server' | Should -Be 'server'
    }
}

Describe 'Script parses cleanly' {
    It 'has no parse errors' {
        $errs = $null
        [System.Management.Automation.Language.Parser]::ParseFile(
            $script:ScriptPath, [ref]$null, [ref]$errs) | Out-Null
        $errs | Should -BeNullOrEmpty
    }
}
