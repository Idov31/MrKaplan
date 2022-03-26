Import-Module .\Modules\Elevate.psm1
function Clear-Registry {
    param (
        [DateTime]
        $time,

        [String[]]
        $users
    )
    
    return $(Clear-BamKey $time $users)
}

function Clear-BamKey {
    param (
        [DateTime]
        $time,

        [String[]]
        $users
    )
    
    if (!$(Invoke-TokenManipulation)) {
        return $false
    }

    $bamKey = "HKLM:\SYSTEM\ControlSet001\Services\bam\State\UserSettings"

    foreach ($user in $users) {
        $sid = $(New-Object System.Security.Principal.NTAccount($user)).Translate([System.Security.Principal.SecurityIdentifier]).Value

        # Checking if the user has bam key.
        if (!(Test-Path "$($bamKey)\$($sid)")) {
            continue
        }
        $userBamKey = Get-Item "$($bamKey)\$($sid)"

        # Searching for values created within the range of the timespan.
        foreach ($valueName in $userBamKey.GetValueNames()) {
            if ($valueName -eq "Version" -or $valueName -eq "SequenceNumber") {
                continue
            }

            $timestamp = Get-Date ([DateTime]::FromFileTimeUtc([bitconverter]::ToInt64($($userBamKey.GetValue($valueName))[0..7],0)))
            $delta = $timestamp - $time
            
            if ($delta -gt 0) {
		        Remove-ItemProperty -Path "$($bamKey)\$($sid)" -Name $valueName
            }
        }
    }
    Write-Host "[+] Removed bam key artifacts!" -ForegroundColor Green
    Invoke-RevertToSelf

    return $true
}

Export-ModuleMember -Function Clear-Registry