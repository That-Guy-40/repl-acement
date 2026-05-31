PowerShell Script Plan — `New-RemoteApp.ps1`
============================================

Design document for a PowerShell helper that automates the RemoteApp workflow
described in [`README.md`](README.md): generate a RemoteApp `.rdp` file, with
optional host-side registry setup and an optional SSH tunnel.

This was the **plan**; it captures scope, parameters, behavior, and edge cases.
It has since been implemented as [`New-RemoteApp.ps1`](New-RemoteApp.ps1), with
tests in [`New-RemoteApp.Tests.ps1`](New-RemoteApp.Tests.ps1). The document is
kept as design rationale.


Goals
-----

1. Generate a valid RemoteApp `.rdp` file for a given executable + remote host,
   so a single remote app opens as a seamless local window.
2. Optionally launch it immediately (`mstsc`).
3. Optionally wrap the connection in an SSH tunnel for encryption.
4. Optionally apply the host-side `TSAppAllowList` registry flag (when run on
   the host, elevated).

Non-goals (at least for v1):

- Full RDS / RemoteApp Collection publishing on Windows Server.
- Managing TLS certificates or RD Gateway configuration.
- Cross-version GUI; this is a CLI-first script.


Usage sketch
------------

```powershell
# Simplest: generate an .rdp for Notepad on a host and launch it.
.\New-RemoteApp.ps1 -RemoteHost 192.168.1.50 `
                    -Program 'C:\Windows\System32\notepad.exe' `
                    -AppName Notepad -Launch

# Encrypted via SSH tunnel (opens ssh -L, points .rdp at localhost:13389).
.\New-RemoteApp.ps1 -RemoteHost server.lan -SshUser alice `
                    -Program 'C:\Program Files\App\app.exe' `
                    -AppName App -UseSshTunnel -Launch

# Just write the .rdp file somewhere, don't launch.
.\New-RemoteApp.ps1 -RemoteHost 10.0.0.5 -Program 'C:\tools\foo.exe' `
                    -AppName Foo -OutFile .\foo.rdp

# Run ON THE HOST, elevated, to enable arbitrary-RemoteApp launching.
.\New-RemoteApp.ps1 -EnableHostAllowList
```


Parameters
----------

| Parameter | Type | Required | Default | Purpose |
|-----------|------|----------|---------|---------|
| `-RemoteHost` | string | yes (client mode) | — | Hostname/IP of the remote Windows machine |
| `-Program` | string | yes (client mode) | — | Full path to the remote executable |
| `-AppName` | string | no | derived from `-Program` filename | Display name for the RemoteApp window |
| `-CmdLine` | string | no | `''` | Arguments passed to the remote program |
| `-RdpPort` | int | no | `3389` | RDP port on the host (or tunnel target) |
| `-OutFile` | string | no | `"$env:TEMP\<AppName>.rdp"` | Where to write the `.rdp` |
| `-Launch` | switch | no | off | Launch immediately via `mstsc` after writing |
| `-UseSshTunnel` | switch | no | off | Open `ssh -L <Local>:localhost:<RdpPort>` and target localhost |
| `-SshUser` | string | when `-UseSshTunnel` | — | SSH username |
| `-LocalTunnelPort` | int | no | `13389` | Local port for the SSH tunnel |
| `-EnableHostAllowList` | switch | no | off | **Host mode**: set the `TSAppAllowList` registry flag (requires elevation) |
| `-WhatIf` / `-Confirm` | common | — | — | Standard `SupportsShouldProcess` dry-run/confirm |


Parameter sets
--------------

Use PowerShell parameter sets to keep modes mutually exclusive:

- **`ClientGenerate`** (default): `-RemoteHost`, `-Program`, … → write/launch `.rdp`.
- **`HostSetup`**: `-EnableHostAllowList` → registry-only, no `.rdp`.

`-UseSshTunnel` lives within `ClientGenerate` and makes `-SshUser` mandatory
(enforce in `begin{}` rather than via attributes, since conditional-required
isn't expressible declaratively).


Behavior / control flow
------------------------

```
param(...)

begin:
  - Validate parameter combinations (tunnel ⇒ SshUser; host mode is standalone).
  - If -EnableHostAllowList:
      * Assert elevation (see "Elevation check").
      * Set HKLM TSAppAllowList\fDisabledAllowList = 1 (ShouldProcess-guarded).
      * Report and exit.

process (client mode):
  - Derive AppName from Program filename if not supplied.
  - Decide target address:
      * If -UseSshTunnel: address = "localhost:<LocalTunnelPort>"
        and start `ssh -N -L <LocalTunnelPort>:localhost:<RdpPort> <SshUser>@<RemoteHost>`
        as a background process (capture PID for later cleanup / message).
      * Else: address = "<RemoteHost>:<RdpPort>".
  - Build the .rdp content from a template (see below).
  - Write to OutFile (ShouldProcess-guarded). Emit the path.
  - If -Launch: Start-Process mstsc.exe -ArgumentList "`"$OutFile`""

end:
  - If a tunnel was started and -Launch was NOT used, remind the user the
    tunnel process is still running and how to stop it.
```


`.rdp` template
---------------

Produced via a here-string with interpolated values:

```
full address:s:{ADDRESS}
remoteapplicationmode:i:1
remoteapplicationname:s:{APPNAME}
remoteapplicationprogram:s:{PROGRAM}
remoteapplicationcmdline:s:{CMDLINE}
disableremoteappcapscheck:i:1
prompt for credentials on client:i:1
```

Notes:
- Write as **UTF-8 without BOM** (or ANSI). `mstsc` is picky about a UTF-8 BOM
  on some Windows builds — `Set-Content -Encoding utf8` in Windows PowerShell
  5.1 emits a BOM, so use `[System.IO.File]::WriteAllText` with a
  `UTF8Encoding($false)` to be safe.
- Use CRLF line endings.


Helper functions
----------------

- `Test-IsElevated` — returns `$true` if the current process is in the
  Administrators role:
  ```powershell
  ([Security.Principal.WindowsPrincipal] `
     [Security.Principal.WindowsIdentity]::GetCurrent()
  ).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
  ```
- `New-RdpContent` — pure function: takes the resolved fields, returns the
  `.rdp` string. Keep it side-effect-free so it's unit-testable.
- `Start-RdpSshTunnel` — starts the background `ssh` process, returns the
  `Process` object.


Edge cases & validation
------------------------

- **Program path with spaces** — keep the path unquoted *inside* the `.rdp`
  (RDP fields are not shell-quoted); quote only when passing `-OutFile` to
  `mstsc`.
- **AppName derivation** — `[IO.Path]::GetFileNameWithoutExtension($Program)`;
  guard against empty.
- **Tunnel without ssh present** — check `Get-Command ssh -ErrorAction Ignore`;
  fail with a clear message pointing at the OpenSSH optional feature.
- **Host allow-list without elevation** — detect and instruct the user to
  re-run from an elevated prompt rather than failing cryptically.
- **Port already in use** (tunnel) — `ssh -L` will error; surface its stderr.
- **Non-Windows / PowerShell Core on Linux** — `mstsc` and the registry path
  don't exist; gate launch/host-setup behind `$IsWindows`.


Safety / correctness
---------------------

- Declare `[CmdletBinding(SupportsShouldProcess, ConfirmImpact='Medium')]` so
  `-WhatIf` previews the registry write, file write, and `mstsc` launch.
- Treat the registry change as **medium impact** — it weakens host
  allow-listing; require confirmation (or `-Force`/explicit `-Confirm:$false`).
- Never embed credentials in the `.rdp`; rely on
  `prompt for credentials on client:i:1`.
- Emit objects, not just text, where reasonable (e.g. return a small object
  with `OutFile`, `Address`, `TunnelPid`) so the script composes in pipelines.


Testing plan
------------

- **Pester unit tests** for `New-RdpContent`: given fixed inputs, assert the
  exact field lines, address selection (tunnel vs direct), and AppName
  derivation. This is the pure, OS-independent core and can run on the CI
  Linux box.
- **Manual / integration** (Windows only): generate against a lab host, verify
  `mstsc` opens the single app seamlessly; verify the SSH-tunnel path; verify
  the registry switch on a throwaway VM.
- **`-WhatIf` smoke test**: confirm no file is written and no process launched.


Open questions
--------------

1. Should v1 manage **closing** the SSH tunnel automatically (e.g. trap on
   exit), or just report the PID? Leaning toward report-only for v1.
2. Provide a companion `Remove-RemoteApp.ps1` to revert the host registry flag?
3. Should we offer a `-Multimon` / resolution / clipboard-redirect set of
   passthrough flags, or keep the `.rdp` minimal for v1? (Lean minimal.)


Future extensions
-----------------

- Optional GUI front-end (WPF/WinForms) listing common apps.
- RD Gateway support for traversal without a manual SSH tunnel.
- Saved "profiles" (host + app presets) in a small JSON config.
