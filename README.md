# Advanced Windows Root Cause Analyzer

A PowerShell toolkit for L2/L3 Windows root-cause triage and selected guarded repairs.

## Diagnostic script

```powershell
powershell.exe -ExecutionPolicy Bypass -File .\Advanced_Windows_Root_Cause_Analyzer.ps1
```

## Repair script

```powershell
powershell.exe -ExecutionPolicy Bypass -File .\Advanced_Windows_Repair_Toolkit.ps1 -RepairSystemFiles -DryRun
```

Examples:

```powershell
.\Advanced_Windows_Repair_Toolkit.ps1 -RestartService Winmgmt,wuauserv
.\Advanced_Windows_Repair_Toolkit.ps1 -RepairSystemFiles
.\Advanced_Windows_Repair_Toolkit.ps1 -SalvageWmiRepository
.\Advanced_Windows_Repair_Toolkit.ps1 -ResetNetworkStack
.\Advanced_Windows_Repair_Toolkit.ps1 -ClearEventLogArchive
```

## What the repair does

- Restarts explicitly selected Windows services.
- Runs DISM RestoreHealth and System File Checker.
- Verifies and salvages the WMI repository using supported `winmgmt` operations.
- Resets Winsock and TCP/IP and records the reset output.
- Can export System and Application logs before clearing them when explicitly selected.
- Captures operating-system, disk, failed-service and error-event state before and after repair.
- Supports `-DryRun`, confirmation prompts, logs and clear exit codes.

## Safety

Network reset normally requires a reboot. Event-log clearing is optional and exports EVTX backups first. Use the diagnostic report to choose targeted repairs rather than running every action automatically.

## Author

Dewald Pretorius — L2 IT Support Engineer
