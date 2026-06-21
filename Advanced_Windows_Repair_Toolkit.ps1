[CmdletBinding(SupportsShouldProcess=$true,ConfirmImpact='High')]
param(
 [string[]]$RestartService,
 [switch]$RepairSystemFiles,
 [switch]$SalvageWmiRepository,
 [switch]$ResetNetworkStack,
 [switch]$ClearEventLogArchive,
 [switch]$DryRun,[switch]$Yes,
 [string]$OutputPath=(Join-Path $env:ProgramData 'AdvancedWindowsRepair')
)
$ErrorActionPreference='Stop';$script:Failures=0;$script:Actions=0
$run=Join-Path $OutputPath (Get-Date -Format yyyyMMdd_HHmmss);New-Item -ItemType Directory $run -Force|Out-Null
$log=Join-Path $run 'repair.log';$before=Join-Path $run 'before.json';$after=Join-Path $run 'after.json'
function Log($m){"$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss') $m"|Tee-Object -FilePath $log -Append}
function Admin{$p=[Security.Principal.WindowsPrincipal]::new([Security.Principal.WindowsIdentity]::GetCurrent());$p.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)}
function State{[pscustomobject]@{Collected=Get-Date;OS=Get-CimInstance Win32_OperatingSystem|Select-Object Caption,BuildNumber,LastBootUpTime,FreePhysicalMemory;Disk=Get-Volume|Select-Object DriveLetter,HealthStatus,SizeRemaining,Size;FailedServices=Get-CimInstance Win32_Service|Where-Object {$_.StartMode -eq 'Auto' -and $_.State -ne 'Running'}|Select-Object Name,State,StartMode,ExitCode;SystemErrors=Get-WinEvent -FilterHashtable @{LogName='System';Level=2;StartTime=(Get-Date).AddHours(-24)} -MaxEvents 100 -ErrorAction SilentlyContinue|Group-Object ProviderName,Id|Sort-Object Count -Descending|Select-Object -First 20 Count,Name}}
function Act($d,[scriptblock]$a){$script:Actions++;Log $d;if($DryRun){Log "DRY-RUN: $d";return};try{&$a;Log "SUCCESS: $d"}catch{$script:Failures++;Log "FAILED: $d - $($_.Exception.Message)"}}
State|ConvertTo-Json -Depth 6|Set-Content $before -Encoding UTF8
if(-not($RestartService -or $RepairSystemFiles -or $SalvageWmiRepository -or $ResetNetworkStack -or $ClearEventLogArchive)){Write-Error 'Choose at least one repair action.';exit 2}
if(-not $DryRun -and -not(Admin)){Write-Error 'Run from elevated PowerShell.';exit 4}
if(-not $Yes -and -not $DryRun){if((Read-Host 'Apply selected root-cause repairs? Type YES') -ne 'YES'){Log 'Cancelled.';exit 10}}
foreach($s in @($RestartService)){Get-Service $s -ErrorAction Stop|Out-Null;Act "Restarting service $s" {Restart-Service $s -Force}}
if($RepairSystemFiles){Act 'Running DISM RestoreHealth' {$p=Start-Process dism.exe -ArgumentList '/Online','/Cleanup-Image','/RestoreHealth' -Wait -PassThru -NoNewWindow;if($p.ExitCode){throw "DISM exited $($p.ExitCode)"}};Act 'Running System File Checker' {$p=Start-Process sfc.exe -ArgumentList '/scannow' -Wait -PassThru -NoNewWindow;if($p.ExitCode -notin 0,1){throw "SFC exited $($p.ExitCode)"}}}
if($SalvageWmiRepository){Act 'Checking WMI repository' {& winmgmt.exe /verifyrepository|Out-File (Join-Path $run 'wmi-verify.txt');if($LASTEXITCODE -ne 0){throw "verifyrepository exited $LASTEXITCODE"}};Act 'Salvaging WMI repository' {& winmgmt.exe /salvagerepository|Out-File (Join-Path $run 'wmi-salvage.txt');if($LASTEXITCODE -ne 0){throw "salvagerepository exited $LASTEXITCODE"}}}
if($ResetNetworkStack){Act 'Resetting Winsock catalog' {& netsh.exe winsock reset|Out-Null;if($LASTEXITCODE){throw 'Winsock reset failed'}};Act 'Resetting TCP/IP stack' {& netsh.exe int ip reset (Join-Path $run 'netsh-ip-reset.txt')|Out-Null;if($LASTEXITCODE){throw 'IP reset failed'}}}
if($ClearEventLogArchive){Act 'Exporting System and Application logs before clearing' {& wevtutil.exe epl System (Join-Path $run 'System.evtx');& wevtutil.exe epl Application (Join-Path $run 'Application.evtx')};Act 'Clearing System and Application event logs' {& wevtutil.exe cl System;& wevtutil.exe cl Application}}
Start-Sleep 3;State|ConvertTo-Json -Depth 6|Set-Content $after -Encoding UTF8
if($script:Failures){Log "Completed with $script:Failures failure(s).";exit 20};Log "Repair completed. Actions: $script:Actions";exit 0
