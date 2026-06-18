#requires -Version 5.1
<#
.SYNOPSIS
    Advanced Windows Root Cause Analyzer.
.DESCRIPTION
    Read-only Windows root-cause triage reporter for L2/L3 escalation.
#>
[CmdletBinding()]
param([int]$Hours=48,[string]$OutputPath)
$RunStamp=Get-Date -Format 'yyyyMMdd_HHmmss'
if([string]::IsNullOrWhiteSpace($OutputPath)){$OutputPath=Join-Path ([Environment]::GetFolderPath('Desktop')) 'Root_Cause_Reports'}
New-Item -Path $OutputPath -ItemType Directory -Force|Out-Null
function Export-Data{param($Name,$Data)$Data|Export-Csv (Join-Path $OutputPath "$Name.csv") -NoTypeInformation -Encoding UTF8;$Data|ConvertTo-Json -Depth 6|Set-Content (Join-Path $OutputPath "$Name.json") -Encoding UTF8}
$os=Get-CimInstance Win32_OperatingSystem;$cs=Get-CimInstance Win32_ComputerSystem;$start=(Get-Date).AddHours(-1*$Hours)
$summary=[PSCustomObject]@{Computer=$env:COMPUTERNAME;OS=$os.Caption;Build=$os.BuildNumber;LastBoot=$os.LastBootUpTime;MemoryGB=[math]::Round($cs.TotalPhysicalMemory/1GB,2);Generated=Get-Date}
$disks=Get-CimInstance Win32_LogicalDisk -Filter "DriveType=3"|Select-Object DeviceID,VolumeName,@{n='SizeGB';e={[math]::Round($_.Size/1GB,2)}},@{n='FreeGB';e={[math]::Round($_.FreeSpace/1GB,2)}}
$services=Get-Service|Where-Object {$_.Status -ne 'Running' -and $_.StartType -eq 'Automatic'}|Select-Object Name,DisplayName,Status,StartType
$events=foreach($log in 'System','Application'){Get-WinEvent -FilterHashtable @{LogName=$log;Level=1,2,3;StartTime=$start} -ErrorAction SilentlyContinue|Select-Object @{n='Log';e={$log}},TimeCreated,Id,ProviderName,LevelDisplayName,Message}
$topIds=$events|Group-Object Log,Id|Sort-Object Count -Descending|Select-Object -First 20 Count,Name
$cpu=Get-Process|Sort-Object CPU -Descending|Select-Object -First 10 Name,Id,CPU,WorkingSet64
$reboot=(Test-Path 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\WindowsUpdate\Auto Update\RebootRequired') -or (Test-Path 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Component Based Servicing\RebootPending')
$hints=@()
if($reboot){$hints+=[PSCustomObject]@{Area='Reboot';Finding='Pending reboot indicator';Recommendation='Restart may be required before further troubleshooting.'}}
$disks|Where-Object {$_.FreeGB -lt 10}|ForEach-Object{$hints+=[PSCustomObject]@{Area='Disk';Finding="Low free space on $($_.DeviceID)";Recommendation='Low disk space can cause performance, update, and app issues.'}}
if(@($services).Count -gt 0){$hints+=[PSCustomObject]@{Area='Services';Finding='Automatic services not running';Recommendation='Review service report for services linked to the symptom.'}}
Export-Data "summary_$RunStamp" @($summary);Export-Data "disks_$RunStamp" $disks;Export-Data "auto_services_not_running_$RunStamp" $services;Export-Data "events_$RunStamp" $events;Export-Data "top_event_ids_$RunStamp" $topIds;Export-Data "top_cpu_$RunStamp" $cpu;Export-Data "root_cause_hints_$RunStamp" $hints
$html="<h1>Windows Root Cause Analyzer - $env:COMPUTERNAME</h1><p>Generated $(Get-Date)</p><h2>Hints</h2>$($hints|ConvertTo-Html -Fragment)<h2>Top Events</h2>$($topIds|ConvertTo-Html -Fragment)<h2>Disks</h2>$($disks|ConvertTo-Html -Fragment)"
$html|ConvertTo-Html -Title 'Root Cause Analyzer'|Set-Content (Join-Path $OutputPath "root_cause_$RunStamp.html") -Encoding UTF8
$hints|Format-Table -AutoSize -Wrap
Write-Host "Reports saved to: $OutputPath" -ForegroundColor Green
Start-Process explorer.exe -ArgumentList "`"$OutputPath`"" -ErrorAction SilentlyContinue
