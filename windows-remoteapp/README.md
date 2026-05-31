Windows Remote Single-App GUI (the `ssh -X` equivalent)
=======================================================

How to run a single application's GUI **remotely** but have its window appear
as a normal, seamless window on your **local** desktop — the Windows analogue
of Unix `ssh -X` / X11 forwarding, without the bloat of a full remote desktop
session.

> **TL;DR** — On Windows the closest native equivalent is **RemoteApp** over
> RDP: the process runs on the remote host, but only the app window streams to
> you. For security, tunnel the RDP connection through SSH. If the remote app
> is a Linux/X11 app, use real `ssh -X` with a local X server instead.


Why this isn't just `ssh -X`
----------------------------

With `ssh -X`, the application process runs on the **remote** machine while
its rendering happens **locally** — the local box acts as a network-transparent
X11 display server.

Native Windows GUI apps don't use X11. They render through Win32 / GDI / the
Desktop Window Manager (DWM), none of which is network-transparent the way the
X protocol is. So a true "process remote, pixels local" experience on Windows
needs either:

- **RDP-based streaming** (RemoteApp) — Microsoft's own remoting protocol, or
- **X11 emulation** — only useful when the remote app actually speaks X11
  (Linux hosts, WSL apps).


The approaches at a glance
--------------------------

| Approach | Process runs | Displays on | Best when |
|----------|--------------|-------------|-----------|
| **RemoteApp (RDP)** | Remote | Local | Remote host is Windows; you want one seamless app window |
| **SSH-tunneled RemoteApp** | Remote | Local | Same, but you want it encrypted / over an existing SSH pipe |
| **`ssh -X` + local X server** | Remote | Local | Remote app is Linux/X11 (or WSL) |
| **WSLg** | Local (in WSL) | Local | You just want Linux GUI apps *on* your Windows box |


Approach 1 — RemoteApp: a single app over RDP, no full desktop
--------------------------------------------------------------

**RemoteApp** publishes a single executable so it streams over RDP and appears
as an ordinary local-looking window — no remote wallpaper, taskbar, or shell.
The app itself runs on the remote host.

### Host-side setup (the remote Windows machine)

The supported path is a Windows Server with the Remote Desktop Services (RDS)
role and proper RemoteApp publishing. On non-Server SKUs (Windows 10/11 Pro)
you can enable the allow-list bypass so *any* executable can be launched as a
RemoteApp:

```bat
:: Run as Administrator on the HOST. Lets clients launch arbitrary RemoteApps.
reg add "HKLM\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Terminal Server\TSAppAllowList" ^
    /v fDisabledAllowList /t REG_DWORD /d 1 /f
```

Remote Desktop must also be enabled on the host (System ▸ Remote Desktop, or
via `SystemPropertiesRemote`).

### Client-side: a hand-crafted `.rdp` file

A RemoteApp connection is just an `.rdp` file with the RemoteApp flags set.
Point `remoteapplicationprogram` at the executable you want:

```
full address:s:REMOTE_HOST_OR_IP
remoteapplicationmode:i:1
remoteapplicationname:s:Notepad
remoteapplicationprogram:s:C:\Windows\System32\notepad.exe
remoteapplicationcmdline:s:
disableremoteappcapscheck:i:1
prompt for credentials on client:i:1
```

Double-click it and the app opens as a seamless window, running on the remote
box. The PowerShell script planned in
[`POWERSHELL_SCRIPT_PLAN.md`](POWERSHELL_SCRIPT_PLAN.md) automates generating
this file (and optionally the host registry tweak).

### Caveats

- Microsoft only **licenses** concurrent interactive RDP sessions on Server
  SKUs. On Windows 10/11 Pro it works technically, but connecting logs out the
  physical console user (single-session limitation).
- The `TSAppAllowList` bypass is an **unsupported configuration** on client
  SKUs. Fine for a lab / personal machine; not for production.
- Home editions can't host RDP at all (no RDP server). They can still *be the
  client*.


Approach 2 — Tunnel RemoteApp over SSH (the secure combo)
---------------------------------------------------------

If your real goal is "I have SSH access and want a GUI securely," forward the
RDP port through SSH and point RemoteApp at the local end of the tunnel.

Windows ships OpenSSH, so from the **local** machine:

```powershell
# Forward local port 13389 to the remote host's RDP port (3389) over SSH.
ssh -L 13389:localhost:3389 user@remote-host
```

Then set `full address:s:localhost:13389` in the `.rdp` file from Approach 1.
Result: a single remote app window, encrypted end-to-end through SSH, with no
full desktop — the spiritual twin of `ssh -X`.


Approach 3 — Real X11 forwarding (only for X11 apps)
----------------------------------------------------

`ssh -X` / `ssh -Y` works from Windows OpenSSH, but only helps when the
**remote** app speaks X11 (Linux host, or a WSL app). You run a local X server
and forward the display:

1. Install a local X server: **VcXsrv**, **X410**, or **MobaXterm**.
2. Forward the display:

   ```powershell
   ssh -Y user@linux-host
   # then launch the X11 app; it renders on your Windows X server
   ```

This does **not** work for native Win32 apps — they never emit X11.


Approach 4 — WSLg (Linux GUI apps locally)
------------------------------------------

If you don't actually need *remote* execution and just want Linux GUI apps on
Windows, **WSLg** (built into Windows 11 and recent Windows 10) runs them
locally with no X-server setup. Mentioned for completeness; it's not remoting.


Decision guide
--------------

- Remote app, local seamless window, Windows host → **Approach 1 (RemoteApp)**
- Same, but encrypted / over SSH → **Approach 2 (SSH-tunneled RemoteApp)**
- Remote app is Linux/X11/WSL → **Approach 3 (`ssh -X` + X server)**
- Just want Linux GUI apps on Windows → **Approach 4 (WSLg)**


Security notes
--------------

- Never expose raw RDP (3389) to the internet. Use Approach 2 (SSH tunnel), a
  VPN, or RD Gateway.
- The `TSAppAllowList` bypass weakens the host's RemoteApp allow-listing — only
  apply it on machines you control.
- Prefer NLA (Network Level Authentication) on the host and strong credentials.


The helper script
-----------------

[`New-RemoteApp.ps1`](New-RemoteApp.ps1) implements the workflow above:

```powershell
# Generate an .rdp for Notepad on a host and launch it as a seamless window.
.\New-RemoteApp.ps1 -RemoteHost 192.168.1.50 `
                    -Program 'C:\Windows\System32\notepad.exe' -Launch

# Encrypted via SSH tunnel (opens ssh -L, points the .rdp at localhost:13389).
.\New-RemoteApp.ps1 -RemoteHost server.lan -SshUser alice `
                    -Program 'C:\Program Files\App\app.exe' -UseSshTunnel -Launch

# Just write the .rdp file, don't launch (works on any OS, incl. Linux).
.\New-RemoteApp.ps1 -RemoteHost 10.0.0.5 -Program 'C:\tools\foo.exe' -OutFile .\foo.rdp

# Run ON THE HOST, elevated, to allow launching arbitrary RemoteApps.
.\New-RemoteApp.ps1 -EnableHostAllowList
```

It supports `-WhatIf`/`-Confirm`, derives the app name from the program path,
writes UTF-8 (no BOM) with CRLF endings, and emits a result object. Tests live
in [`New-RemoteApp.Tests.ps1`](New-RemoteApp.Tests.ps1) (Pester 5).


See also
--------

- [`POWERSHELL_SCRIPT_PLAN.md`](POWERSHELL_SCRIPT_PLAN.md) — the design behind
  `New-RemoteApp.ps1`.
