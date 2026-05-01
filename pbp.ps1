#Requires -Version 5.1
<#
.SYNOPSIS
    Samsung G7 Monitor Control Script

.DESCRIPTION
    Controls Samsung G7 monitor settings via the Windows Monitor Configuration API (dxva2.dll).
    Supports PBP (Picture by Picture) toggle and input source switching.

.PARAMETER PBP
    Turn PBP mode on or off. Accepted values: on, off

.PARAMETER Input1
    Set the primary input source. Accepted values: dp, hdmi

.PARAMETER Input2
    Set the PBP secondary input source. Accepted values: hdmi1, hdmi2

.EXAMPLE
    .\Monitor-Control.ps1 -PBP on
    .\Monitor-Control.ps1 -PBP off
    .\Monitor-Control.ps1 -Input1 dp
    .\Monitor-Control.ps1 -Input1 hdmi
    .\Monitor-Control.ps1 -Input2 hdmi1
    .\Monitor-Control.ps1 -Input2 hdmi2
    .\Monitor-Control.ps1 -PBP on -Input1 dp -Input2 hdmi1
#>

[CmdletBinding()]
param (
    [ValidateSet("on", "off")]
    [string]$PBP,

    [ValidateSet("dp", "hdmi")]
    [string]$Input1,

    [ValidateSet("hdmi1", "hdmi2")]
    [string]$Input2
)

# --- Constants ---
$VCP_INPUT_SOURCE = 0x60
$VCP_PBP          = 0xE2
$VCP_PBP_INPUT2   = 0xE3

$INPUT_DISPLAYPORT = 15
$INPUT_HDMI1       = 17

$PBP_ON  = 1
$PBP_OFF = 0

$PBP_INPUT2_HDMI1 = 256
$PBP_INPUT2_HDMI2 = 257

# --- Load Windows Monitor API ---
if (-not ([System.Management.Automation.PSTypeName]'MonitorAPI').Type) {
Add-Type @"
using System;
using System.Runtime.InteropServices;

public class MonitorAPI {
    [DllImport("dxva2.dll")]
    public static extern bool SetVCPFeature(IntPtr hMonitor, byte bVCPCode, uint dwNewValue);

    [DllImport("dxva2.dll")]
    public static extern bool GetVCPFeatureAndVCPFeatureReply(IntPtr hMonitor, byte bVCPCode, IntPtr pvct, ref uint pdwCurrentValue, ref uint pdwMaximumValue);

    [DllImport("dxva2.dll")]
    public static extern bool GetNumberOfPhysicalMonitorsFromHMONITOR(IntPtr hMonitor, ref uint pdwNumberOfPhysicalMonitors);

    [DllImport("dxva2.dll")]
    public static extern bool GetPhysicalMonitorsFromHMONITOR(IntPtr hMonitor, uint dwPhysicalMonitorArraySize, [Out] PHYSICAL_MONITOR[] pPhysicalMonitorArray);

    [DllImport("dxva2.dll")]
    public static extern bool DestroyPhysicalMonitors(uint dwPhysicalMonitorArraySize, [In] PHYSICAL_MONITOR[] pPhysicalMonitorArray);

    [DllImport("user32.dll")]
    public static extern IntPtr MonitorFromWindow(IntPtr hwnd, uint dwFlags);

    [DllImport("user32.dll")]
    public static extern IntPtr GetDesktopWindow();

    [StructLayout(LayoutKind.Sequential, CharSet = CharSet.Auto)]
    public struct PHYSICAL_MONITOR {
        public IntPtr hPhysicalMonitor;
        [MarshalAs(UnmanagedType.ByValTStr, SizeConst = 128)]
        public string szPhysicalMonitorDescription;
    }
}
"@
} # end if type not exists

# --- Get physical monitor handle ---
function Get-SamsungMonitorHandle {
    $hMonitor = [MonitorAPI]::MonitorFromWindow([MonitorAPI]::GetDesktopWindow(), 1)

    $count = 0
    [MonitorAPI]::GetNumberOfPhysicalMonitorsFromHMONITOR($hMonitor, [ref]$count) | Out-Null

    if ($count -eq 0) {
        throw "No physical monitors found."
    }

    $physicalMonitors = New-Object MonitorAPI+PHYSICAL_MONITOR[] $count
    [MonitorAPI]::GetPhysicalMonitorsFromHMONITOR($hMonitor, $count, $physicalMonitors) | Out-Null

    # Test each monitor handle for DDC/CI responsiveness
    foreach ($pm in $physicalMonitors) {
        $current = 0; $max = 0
        $result = [MonitorAPI]::GetVCPFeatureAndVCPFeatureReply($pm.hPhysicalMonitor, $VCP_INPUT_SOURCE, [IntPtr]::Zero, [ref]$current, [ref]$max)
        if ($result) {
            return $pm
        }
    }

    throw "Could not find a responsive monitor handle. Ensure DDC/CI is active."
}

# --- Set VCP Feature ---
function Set-MonitorVCP {
    param(
        [MonitorAPI+PHYSICAL_MONITOR]$Monitor,
        [byte]$VCPCode,
        [uint32]$Value,
        [string]$Description
    )
    $result = [MonitorAPI]::SetVCPFeature($Monitor.hPhysicalMonitor, $VCPCode, $Value)
    if ($result) {
        Write-Host "OK  $Description" -ForegroundColor Green
    } else {
        Write-Warning "FAILED  $Description"
    }
}

# --- Main ---
if (-not $PBP -and -not $Input1 -and -not $Input2) {
    Write-Host "Samsung G7 Monitor Control" -ForegroundColor Cyan
    Write-Host ""
    Write-Host "Usage:"
    Write-Host "  .\Monitor-Control.ps1 -PBP on|off"
    Write-Host "  .\Monitor-Control.ps1 -Input1 dp|hdmi"
    Write-Host "  .\Monitor-Control.ps1 -Input2 hdmi1|hdmi2"
    Write-Host "  .\Monitor-Control.ps1 -PBP on -Input1 dp -Input2 hdmi1"
    exit 0
}

try {
    Write-Host "Connecting to monitor..." -ForegroundColor Cyan
    $monitor = Get-SamsungMonitorHandle

    if ($Input1) {
        switch ($Input1) {
            "dp"   { Set-MonitorVCP $monitor $VCP_INPUT_SOURCE $INPUT_DISPLAYPORT "Input 1 -> DisplayPort" }
            "hdmi" { Set-MonitorVCP $monitor $VCP_INPUT_SOURCE $INPUT_HDMI1       "Input 1 -> HDMI 1" }
        }
    }

    if ($Input2) {
        switch ($Input2) {
            "hdmi1" { Set-MonitorVCP $monitor $VCP_PBP_INPUT2 $PBP_INPUT2_HDMI1 "Input 2 -> HDMI 1" }
            "hdmi2" { Set-MonitorVCP $monitor $VCP_PBP_INPUT2 $PBP_INPUT2_HDMI2 "Input 2 -> HDMI 2" }
        }
    }

    if ($PBP) {
        switch ($PBP) {
            "on"  { Set-MonitorVCP $monitor $VCP_PBP $PBP_ON  "PBP -> On" }
            "off" { Set-MonitorVCP $monitor $VCP_PBP $PBP_OFF "PBP -> Off" }
        }
    }
}
catch {
    Write-Error $_.Exception.Message
    exit 1
}