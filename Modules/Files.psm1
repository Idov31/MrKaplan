function Clear-Files {
    param (
        [DateTime]
        $time,

        [String]
        $encodedPowershellHistory,

        [String]
        $user,

        [Boolean]
        $runAsUser
    )
    $res = $true
    Clear-Powershell $encodedPowershellHistory $user
    Clear-InetCache $time $user
    Clear-WindowsHistory $time $user
    Clear-OfficeHistory $time $user

    if (!$runAsUser) {
        if ($(Clear-Prefetches $time) -eq $false) {
            $res = $false
        }
    }

    return $res
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
        return $false
    }

    return $true
}

function Clear-InetCache {
    param (
        [DateTime]
        $time,

        [String]
        $user
    )

    $inetCache = Get-ChildItem "C:\Users\${$user}\AppData\Local\Microsoft\Windows\INetCache" -Force -Recurse -File

    if ($inetCache) {

        # Iterating inet cache.
        foreach ($inet in $inetCache) {
            if ($inet.Name -eq "container.dat") {
                continue
            }
            $delta = $inet.CreationTime - $time
            
            # If the inet cache file created within the range of the wanted timespan. - remove it.
            if ($delta -gt 0) {
                Remove-Item $inet.FullName
            }
        }

        Write-Host "[+] Removed inet cache artifacts!" -ForegroundColor Green
    }
}

function Clear-OfficeHistory {
    param (
        [DateTime]
        $time,

        [String]
        $user
    )

    $officeHistory = Get-ChildItem "C:\Users\$($user)\AppData\Roaming\Microsoft\Office\Recent"

    if ($officeHistory) {

        # Iterating office history.
        foreach ($file in $officeHistory) {

            if ($file.Name -eq "index.dat") {
                continue
            }

            $delta = $file.CreationTime - $time
            
            # If the office history file created within the range of the wanted timespan. - remove it.
            if ($delta -gt 0) {
                Remove-Item $file.FullName
            }
        }

        Write-Host "[+] Removed office history artifacts!" -ForegroundColor Green
    }
}

function Clear-WindowsHistory {
    param (
        [DateTime]
        $time,

        [String]
        $user
    )

    $windowsHistory = Get-ChildItem "C:\Users\$($user)\AppData\Roaming\Microsoft\Windows\Recent" -File

    if ($windowsHistory) {

        # Iterating windows history.
        foreach ($file in $windowsHistory) {
            $delta = $file.CreationTime - $time
            
            # If the windows history file created within the range of the wanted timespan. - remove it.
            if ($delta -gt 0) {
                Remove-Item $file.FullName
            }
        }

        Write-Host "[+] Removed windows history artifacts!" -ForegroundColor Green
    }
}

function Invoke-LogFileToStomp {
    param (
        [String]
        $stompedFilePath
    )

    # Input validation.
    if (!$(Test-Path "MrKaplan-Config.json")) {
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
    $configFile["files"][$stompedFilePath] = @($stompedFileInfo.CreationTime, $stompedFileInfo.LastWriteTime, $stompedFileInfo.LastAccessTime)
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