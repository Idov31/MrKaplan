function Clear-Files {
    param (
        [DateTime]
        $time,

        [String]
        $encodedPowershellHistory,

        [String]
        $user
    )
    
    Clear-Prefetches $time
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

Export-ModuleMember -Function Clear-Files