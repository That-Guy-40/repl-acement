<#
.SYNOPSIS
    Generate (and optionally launch) a RemoteApp .rdp file so a single remote
    application opens as a seamless window on your local desktop — the Windows
    equivalent of `ssh -X`.

.DESCRIPTION
    Two modes:

      Client mode (default) — build a RemoteApp .rdp file targeting a remote
      Windows host, optionally launching it with mstsc and/or wrapping the
      connection in an SSH tunnel for encryption.

      Host mode (-EnableHostAllowList) — set the host-side TSAppAllowList
      registry flag so arbitrary executables can be launched as RemoteApps.
      Must be run elevated, on the host itself.

    See README.md and POWERSHELL_SCRIPT_PLAN.md in this directory for the
    background and design rationale.

.EXAMPLE
    .\New-RemoteApp.ps1 -RemoteHost 192.168.1.50 -Program 'C:\Windows\System32\notepad.exe' -AppName Notepad -Launch

.EXAMPLE
    .\New-RemoteApp.ps1 -RemoteHost server.lan -SshUser alice -Program 'C:\Program Files\App\app.exe' -AppName App -UseSshTunnel -Launch

.EXAMPLE
    .\New-RemoteApp.ps1 -EnableHostAllowList
#>
[CmdletBinding(SupportsShouldProcess, ConfirmImpact = 'Medium', DefaultParameterSetName = 'ClientGenerate')]
param(
    [Parameter(Mandatory, ParameterSetName = 'ClientGenerate')]
    [string] $RemoteHost,

    [Parameter(Mandatory, ParameterSetName = 'ClientGenerate')]
    [string] $Program,

    [Parameter(ParameterSetName = 'ClientGenerate')]
    [string] $AppName,

    [Parameter(ParameterSetName = 'ClientGenerate')]
    [string] $CmdLine = '',

    [Parameter(ParameterSetName = 'ClientGenerate')]
    [ValidateRange(1, 65535)]
    [int] $RdpPort = 3389,

    [Parameter(ParameterSetName = 'ClientGenerate')]
    [string] $OutFile,

    [Parameter(ParameterSetName = 'ClientGenerate')]
    [switch] $Launch,

    [Parameter(ParameterSetName = 'ClientGenerate')]
    [switch] $UseSshTunnel,

    [Parameter(ParameterSetName = 'ClientGenerate')]
    [string] $SshUser,

    [Parameter(ParameterSetName = 'ClientGenerate')]
    [ValidateRange(1, 65535)]
    [int] $LocalTunnelPort = 13389,

    [Parameter(Mandatory, ParameterSetName = 'HostSetup')]
    [switch] $EnableHostAllowList
)

# --------------------------------------------------------------------------
# Helpers (pure where possible, so the core is unit-testable on any platform)
# --------------------------------------------------------------------------

function Test-IsElevated {
    [CmdletBinding()]
    param()
    if (-not $IsWindows -and $PSVersionTable.PSEdition -eq 'Core') {
        # Non-Windows PowerShell Core: no Windows admin concept.
        return $false
    }
    $id = [Security.Principal.WindowsIdentity]::GetCurrent()
    $principal = [Security.Principal.WindowsPrincipal] $id
    return $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
}

function Get-AppNameFromProgram {
    <#
    .SYNOPSIS
        Derive a display name from a program path, treating BOTH '\' and '/'
        as separators so Windows paths resolve correctly even when this script
        runs on a non-Windows box (e.g. generating a .rdp to copy to Windows).
    #>
    [CmdletBinding()]
    [OutputType([string])]
    param([Parameter(Mandatory)] [string] $Program)

    $leaf = ($Program -split '[\\/]')[-1]
    # Strip a trailing extension if present.
    $dot = $leaf.LastIndexOf('.')
    if ($dot -gt 0) { $leaf = $leaf.Substring(0, $dot) }
    return $leaf
}

function New-RdpContent {
    <#
    .SYNOPSIS
        Pure function: build the .rdp file body from resolved fields.
        Side-effect free so it can be unit-tested.
    #>
    [CmdletBinding()]
    [OutputType([string])]
    param(
        [Parameter(Mandatory)] [string] $Address,
        [Parameter(Mandatory)] [string] $AppName,
        [Parameter(Mandatory)] [string] $Program,
        [string] $CmdLine = ''
    )
    $lines = @(
        "full address:s:$Address"
        'remoteapplicationmode:i:1'
        "remoteapplicationname:s:$AppName"
        "remoteapplicationprogram:s:$Program"
        "remoteapplicationcmdline:s:$CmdLine"
        'disableremoteappcapscheck:i:1'
        'prompt for credentials on client:i:1'
    )
    # RDP files use CRLF line endings.
    return ($lines -join "`r`n") + "`r`n"
}

function Write-RdpFile {
    <#
    .SYNOPSIS
        Write .rdp content as UTF-8 *without* BOM (mstsc dislikes a BOM on
        some Windows builds).
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)] [string] $Path,
        [Parameter(Mandatory)] [string] $Content
    )
    $utf8NoBom = [System.Text.UTF8Encoding]::new($false)
    [System.IO.File]::WriteAllText($Path, $Content, $utf8NoBom)
}

function Start-RdpSshTunnel {
    <#
    .SYNOPSIS
        Start a background `ssh -N -L <Local>:localhost:<Remote>` tunnel.
        Returns the Process object.
    #>
    [CmdletBinding()]
    [OutputType([System.Diagnostics.Process])]
    param(
        [Parameter(Mandatory)] [string] $SshUser,
        [Parameter(Mandatory)] [string] $RemoteHost,
        [Parameter(Mandatory)] [int]    $LocalPort,
        [Parameter(Mandatory)] [int]    $RemotePort
    )
    $forward = "{0}:localhost:{1}" -f $LocalPort, $RemotePort
    $target  = "{0}@{1}" -f $SshUser, $RemoteHost
    $argList = @('-N', '-L', $forward, $target)
    Write-Verbose "Starting SSH tunnel: ssh $($argList -join ' ')"
    return Start-Process -FilePath 'ssh' -ArgumentList $argList -PassThru
}

# --------------------------------------------------------------------------
# Host mode: enable the TSAppAllowList bypass
# --------------------------------------------------------------------------

if ($PSCmdlet.ParameterSetName -eq 'HostSetup') {
    if (-not $IsWindows -and $PSVersionTable.PSEdition -eq 'Core') {
        throw 'Host setup (-EnableHostAllowList) is only meaningful on Windows.'
    }
    if (-not (Test-IsElevated)) {
        throw 'Enabling the host allow-list requires an elevated (Administrator) prompt. Re-run as Administrator.'
    }

    $regPath = 'HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Terminal Server\TSAppAllowList'
    $target  = "$regPath\fDisabledAllowList = 1"
    if ($PSCmdlet.ShouldProcess($target, 'Set registry value (weakens RemoteApp allow-listing)')) {
        if (-not (Test-Path $regPath)) {
            New-Item -Path $regPath -Force | Out-Null
        }
        New-ItemProperty -Path $regPath -Name 'fDisabledAllowList' `
            -PropertyType DWord -Value 1 -Force | Out-Null
        Write-Host "Host allow-list bypass enabled. Arbitrary executables may now be launched as RemoteApps." -ForegroundColor Green
        Write-Host "Ensure Remote Desktop is also enabled on this host (SystemPropertiesRemote)." -ForegroundColor Yellow
    }
    return
}

# --------------------------------------------------------------------------
# Client mode: validate, resolve fields, (optionally) tunnel, write, launch
# --------------------------------------------------------------------------

# Conditional-required: tunnel needs an SSH user.
if ($UseSshTunnel -and [string]::IsNullOrWhiteSpace($SshUser)) {
    throw '-UseSshTunnel requires -SshUser.'
}

# Derive AppName from the program filename if not supplied.
if ([string]::IsNullOrWhiteSpace($AppName)) {
    $AppName = Get-AppNameFromProgram -Program $Program
    if ([string]::IsNullOrWhiteSpace($AppName)) {
        throw "Could not derive an application name from -Program '$Program'. Supply -AppName explicitly."
    }
}

# Default output path.
if ([string]::IsNullOrWhiteSpace($OutFile)) {
    $tempDir = if ($env:TEMP) { $env:TEMP } else { [System.IO.Path]::GetTempPath() }
    $OutFile = Join-Path $tempDir "$AppName.rdp"
}

# Resolve the address and (optionally) start the tunnel.
$tunnelProc = $null
if ($UseSshTunnel) {
    if (-not (Get-Command ssh -ErrorAction Ignore)) {
        throw "ssh not found. Install the OpenSSH client (Settings > Optional Features > OpenSSH Client) or add it to PATH."
    }
    $address = "localhost:$LocalTunnelPort"
    if ($PSCmdlet.ShouldProcess("$SshUser@$RemoteHost", "Open SSH tunnel localhost:$LocalTunnelPort -> :$RdpPort")) {
        $tunnelProc = Start-RdpSshTunnel -SshUser $SshUser -RemoteHost $RemoteHost `
            -LocalPort $LocalTunnelPort -RemotePort $RdpPort
    }
}
else {
    $address = "${RemoteHost}:$RdpPort"
}

# Build the .rdp body (pure) and write it.
$content = New-RdpContent -Address $address -AppName $AppName -Program $Program -CmdLine $CmdLine

if ($PSCmdlet.ShouldProcess($OutFile, 'Write RemoteApp .rdp file')) {
    Write-RdpFile -Path $OutFile -Content $content
    Write-Verbose "Wrote .rdp to $OutFile"
}

# Optionally launch via mstsc.
$launched = $false
if ($Launch) {
    if (-not $IsWindows -and $PSVersionTable.PSEdition -eq 'Core') {
        Write-Warning 'mstsc is only available on Windows; skipping -Launch.'
    }
    elseif ($PSCmdlet.ShouldProcess($OutFile, 'Launch with mstsc')) {
        Start-Process -FilePath 'mstsc.exe' -ArgumentList "`"$OutFile`""
        $launched = $true
    }
}

# Remind the user about a lingering tunnel when we didn't launch.
if ($tunnelProc -and -not $launched) {
    Write-Host "SSH tunnel running (PID $($tunnelProc.Id)). Stop it with: Stop-Process -Id $($tunnelProc.Id)" -ForegroundColor Yellow
}

# Emit a result object so the script composes in pipelines.
[pscustomobject]@{
    OutFile   = $OutFile
    Address   = $address
    AppName   = $AppName
    Program   = $Program
    TunnelPid = if ($tunnelProc) { $tunnelProc.Id } else { $null }
    Launched  = $launched
}
