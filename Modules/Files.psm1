function Clear-Files {
    param (
        [DateTime]
        $time,

        [String]
        $encodedPowershellHistory,

        [String]
        $user,

        [Switch]
        $runAsUser
    )
    
    if (!$runAsUser) {
        Clear-Prefetches $time
    }
    Clear-Powershell $encodedPowershellHistory $user
}

function Clear-Powershell {
    param (
        [String]
        $encodedPowershellHistory,

        [String]
        $user
    )
    $powershellHistoryFile = "C:\Users\$($user)\AppData\Roaming\Microsoft\Windows\PowerShell\PSReadLine\ConsoleHost_history.txt"

    # If there is powershell history file - replace it with the saved copy.
    if ($encodedPowershellHistory) {
        [System.Text.Encoding]::UTF8.GetString([System.Convert]::FromBase64String($encodedPowershellHistory)) | Set-Content $powershellHistoryFile -Encoding utf8
    }
}

function Clear-Prefetches {
    param (
        [DateTime]
        $time
    )

    $prefetches = Get-ChildItem "C:\Windows\Prefetch"

    if ($prefetches) {

        # Iterating prefetches.
        foreach ($prefetch in $prefetches) {
            $delta = $prefetch.CreationTime - $time
            
            # If the prefetch file created within the range of the wanted timespan. - remove it.
            if ($delta -gt 0) {
                Remove-Item $prefetch.FullName
            }
        }

        Write-Host "[+] Removed prefetch artifacts!" -ForegroundColor Green
    }
    else {
        Write-Host "[-] Couldn't remove prefetch artifacts, rerun as admin or delete manually." -ForegroundColor Yellow
    }
}

function Invoke-LogFileToStomp {
    param (
        [String]
        $stompedFilePath
    )

    # Input validation.
    if (!Test-Path "MrKaplan-Config.json") {
        Write-Host "[-] Config file doesn't exists, for the first time run this program with start." -ForegroundColor Red
        return $false
    }

    if (!$stompedFilePath) {
        Write-Host "[-] File doesn't exists, for the first time run this program with start." -ForegroundColor Red
        return $false
    }

    # Parsing the config file.
    $configFile = Get-Content "MrKaplan-Config.json" | ConvertFrom-Json | ConvertTo-Hashtable
    
    if (!$configFile) {
        Write-Host "[-] Failed to parse config file." -ForegroundColor Red
        return $false
    }

    if (!$configFile["files"]) {
        $configFile["files"] = @{}   
    }

    # Saving the time stamps.
    $stompedFileInfo = Get-Item $stompedFilePath
    $configFile["files"][$stompedFilePath] = @($stompedFileInfo.CreationTime, $stompedFileInfo.LastAccessTime, $stompedFileInfo.LastWriteTime)
    $configFile | ConvertTo-Json | Out-File "MrKaplan-Config.json"

    return $true
}

function Invoke-StompFiles {
    param (
        [Hashtable]
        $files
    )

    # Stomping every file.
    if ($files) {
        foreach ($file in $files.Keys) {
            $fileInfo = Get-Item $file
            $fileInfo.CreationTime = $files[$file][0]
            $fileInfo.LastWriteTime = $files[$file][1]
            $fileInfo.LastAccessTime = $files[$file][2]
        }
    }
}

Export-ModuleMember -Function Clear-Files
Export-ModuleMember -Function Invoke-LogFileToStomp
Export-ModuleMember -Function Invoke-StompFiles