Import-Module .\Modules\Elevate.psm1
function Clear-Registry {
    param (
        [DateTime]
        $time,

        [String[]]
        $users,

        [Boolean]
        $runAsUser
    )
    $result = $true
    Clear-UserAssist $time $users

    if (!$runAsUser) {
        if (!$(Clear-BamKey $time $users)) {
            $result = $false
        }
    }

    return $result
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

function Clear-UserAssist {
    param (
        [DateTime]
        $time,

        [String[]]
        $users
    )

    # Registring the HKEY_USERS hive.
    New-PSDrive -PSProvider Registry -Name HKU -Root HKEY_USERS
    $userAssistKeyPath = "Software\Microsoft\Windows\CurrentVersion\Explorer\UserAssist"

    foreach ($user in $users) {
        $sid = $(New-Object System.Security.Principal.NTAccount($user)).Translate([System.Security.Principal.SecurityIdentifier]).Value

        # Checking if the user has user assist key.
        if (!(Test-Path "HKU:\$($sid)\$($userAssistKeyPath)")) {
            continue
        }
        $userAssistKey = Get-Item "HKU:\$($sid)\$($userAssistKeyPath)"

        # Searching for values created within the range of the timespan.
        foreach ($subKeyName in $userAssistKey.GetSubKeyNames()) {
            $currentUserAssistKey = Get-Item "HKU:\$($sid)\$($userAssistKeyPath)\$($subKeyName)\Count"

            foreach ($valueName in $currentUserAssistKey.GetValueNames()) {
                if ($valueName -eq "HRZR_PGYFRFFVBA") {
                    continue
                }

                $rawTimestamp = $userAssistKey.GetValue($valueName)

                # To cover the Windows 7 and Windows 7 and onwards versions.
                if ($rawTimestamp.Length -gt 68) {
                    $timestamp = Get-Date ([DateTime]::FromFileTime([bitconverter]::ToInt64($rawTimestamp,60)))
                }
                else {
                    $timestamp = Get-Date ([DateTime]::FromFileTime([bitconverter]::ToInt64($rawTimestamp,8)))
                }

                $delta = $timestamp - $time
                
                if ($delta -gt 0) {
                    Remove-ItemProperty -Path "HKU:\$($sid)\$($userAssistKeyPath)\$($subKeyName)\Count" -Name $valueName
                }
            }
        }
    }
    Write-Host "[+] Removed user assist artifacts!" -ForegroundColor Green
}

Export-ModuleMember -Function Clear-Registry