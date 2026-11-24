# Windows Interactive Browser Launcher (WinSta0\Default + CDP)
# Launches Brave or Chrome visibly on the active physical desktop station
# while keeping a daemon handle alive so background job objects do not close it.

param(
    [string]$BrowserExe = "C:\Program Files\BraveSoftware\Brave-Browser\Application\brave.exe",
    [string]$ProfileDir = "Profile 1",
    [int]$CdpPort = 9224,
    [string]$StartUrl = "https://github.com"
)

$ErrorActionPreference = "SilentlyContinue"

Add-Type @'
using System;
using System.Runtime.InteropServices;

public class DesktopLauncher {
    [StructLayout(LayoutKind.Sequential, CharSet = CharSet.Auto)]
    public struct STARTUPINFO {
        public int cb;
        public string lpReserved;
        public string lpDesktop;
        public string lpTitle;
        public int dwX, dwY, dwXSize, dwYSize;
        public int dwXCountChars, dwYCountChars;
        public int dwFillAttribute;
        public int dwFlags;
        public short wShowWindow;
        public short cbReserved2;
        public IntPtr lpReserved2;
        public IntPtr hStdInput, hStdOutput, hStdError;
    }

    [StructLayout(LayoutKind.Sequential)]
    public struct PROCESS_INFORMATION {
        public IntPtr hProcess;
        public IntPtr hThread;
        public int dwProcessId;
        public int dwThreadId;
    }

    [DllImport("kernel32.dll", SetLastError = true, CharSet = CharSet.Auto)]
    public static extern bool CreateProcess(
        string lpApplicationName,
        string lpCommandLine,
        IntPtr lpProcessAttributes,
        IntPtr lpThreadAttributes,
        bool bInheritHandles,
        uint dwCreationFlags,
        IntPtr lpEnvironment,
        string lpCurrentDirectory,
        [In] ref STARTUPINFO lpStartupInfo,
        out PROCESS_INFORMATION lpProcessInformation
    );

    public static int StartVisible(string exePath, string args, string workDir) {
        STARTUPINFO si = new STARTUPINFO();
        si.cb = Marshal.SizeOf(si);
        si.lpDesktop = @"WinSta0\Default";
        si.dwFlags = 1;
        si.wShowWindow = 3; // Maximized

        PROCESS_INFORMATION pi;
        string cmd = "\"" + exePath + "\" " + args;
        bool ok = CreateProcess(null, cmd, IntPtr.Zero, IntPtr.Zero, false, 0, IntPtr.Zero, workDir, ref si, out pi);
        return ok ? pi.dwProcessId : -1;
    }
}
'@

$args = "--profile-directory=`"$ProfileDir`" --remote-debugging-port=$CdpPort --disable-backgrounding-occluded-windows --disable-renderer-backgrounding `"$StartUrl`""
$workDir = Split-Path -Parent $BrowserExe
$pidLaunched = [DesktopLauncher]::StartVisible($BrowserExe, $args, $workDir)
Write-Host "Launched browser on WinSta0\Default with PID: $pidLaunched (CDP :$CdpPort)"

while ($true) {
    Start-Sleep -Seconds 10
}
