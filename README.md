# Samsung Monitor Control

This simple script can be used to send VCP codes to your Samsung Monitor from a Windows Powershell command line(if it supports it) to change PBP on/off and inputs.

I wrote this because the Samsung Display Manager software did not include a CLI and I wanted to set a button on my stream deck to easily switch between Full screen and PBP settings.

Currently, it only supports switches for turning PBP on or off, and to set Input1 and Input2, but the framework is there to add any other commands, such as brightness, volume, etc.

## Usage
Save the script to your PC, and run it as follows:

PBP On
powershell.exe -ExecutionPolicy Bypass -File E:\Samsung\pbp.ps1 -PBP on -Input1 dp -Input2 hdmi1

PBP Off (using DisplayPort input)
powershell.exe -ExecutionPolicy Bypass -File E:\Samsung\pbp.ps1 -PBP off -Input1 dp

## Background
Even though some VCP codes are documented and used in other tools, I couldn't find the codes for PBP on/off.

So it involved a bit of reverse engineering, here's the rough approach.
* Download and install API Monitor http://www.rohitab.com/apimonitor
* Download and install Samsung Display Manager (SDM) UI
* Using API Monitor, either attach to or start the samsungdisplaymanager.exe process
* In the monitoring panel, create a filter on the module DisplayTookit.dll
* Now, using SDM UI, set the screen how you would like it.  e.g. turn on PBP
* In API Monitor, look for the SetVCFeature API call, and note the numbers
For example, these codes were generated when set the brightness to 37.  16 = the VCP code, 37 = the value
SetVCPFeature ( NULL, 16, 37 )	TRUE		0.0627851

You can repeat this method to find all the codes you need, and then update the Powershell script.
