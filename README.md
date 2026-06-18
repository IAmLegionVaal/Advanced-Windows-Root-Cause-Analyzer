# Advanced Windows Root Cause Analyzer

A read-only PowerShell toolkit for L2/L3 Windows root-cause triage.

## Features

- OS, uptime, disk, service, and pending reboot context
- Recent System and Application event summaries
- Top event IDs and providers
- Recent app crash indicators
- Top CPU and memory processes
- Root-cause hint report for escalation notes
- CSV, JSON, and HTML output

## How to run

```powershell
powershell.exe -ExecutionPolicy Bypass -File .\Advanced_Windows_Root_Cause_Analyzer.ps1
```

## Safety

Diagnostic-only. It reports evidence and does not repair or change the system.
