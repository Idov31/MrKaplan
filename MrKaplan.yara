/*
    A rule to detect MrKaplan.
    Author: Ido Veltzman (Idov31)
    Date: 15-04-2022
*/
rule MrKaplanStandalone {
    meta:
        description = "A rule to detect MrKaplanStandalone."
        author = "Idov31"
        date = "2022-04-15"

    strings:
        $imports1 = /[System.Text.Encoding]::UTF8.GetString([System.Convert]::FromBase64String(.*) | Invoke-Expression/i nocase
        $imports2 = /[System.Text.Encoding]::UTF8.GetString([System.Convert]::FromBase64String(.*) | iex/i nocase
        
        $s1 = "MrKaplan.ps1" ascii nocase
        $s2 = "Clear-Evidence" ascii nocase
        $s3 = "EventLogSettings" ascii nocase
        $s4 = "runAsUser" ascii nocase
        $s5 = "PSHistory" ascii nocase
        $s6 = "C:\Users\$($user)\AppData\Roaming\Microsoft\Windows\PowerShell\PSReadLine\ConsoleHost_history.txt" ascii nocase
        $s7 = "MrKaplan-Config.json" ascii nocase
        $s8 = "Invoke-StompFiles" ascii nocase
        $s9 = "Clear-Files" ascii nocase
        $s10 = "Clear-Registry" ascii nocase
        $s11 = "Invoke-RestoreEtw" ascii nocase
        $s12 = "Invoke-LogFileToStomp" ascii nocase
        $s13 = "Invoke-SuspendEtw" ascii nocase

    conditions:
        any of $imports* and 3 of ($s*)
}

rule MrKaplan {
    meta:
        description = "A rule to detect MrKaplan."
        author = "Idov31"
        date = "2022-04-15"

    strings:
        $imports1 = "Import-Module .\Modules\Registry.psm1" ascii nocase
        $imports2 = "Import-Module .\Modules\Files.psm1" ascii nocase
        $imports3 = "Import-Module .\Modules\Eventlogs.psm1" ascii nocase
        $imports4 = "Import-Module .\Modules\Utils.psm1" ascii nocase
        $imports5 = "ipmo .\Modules\Registry.psm1" ascii nocase
        $imports6 = "ipmo .\Modules\Files.psm1" ascii nocase
        $imports7 = "ipmo .\Modules\Eventlogs.psm1" ascii nocase
        $imports8 = "ipmo .\Modules\Utils.psm1" ascii nocase
        

        $s1 = "MrKaplan.ps1" ascii nocase
        $s2 = "Clear-Evidence" ascii nocase
        $s3 = "EventLogSettings" ascii nocase
        $s4 = "runAsUser" ascii nocase
        $s5 = "PSHistory" ascii nocase
        $s6 = "C:\Users\$($user)\AppData\Roaming\Microsoft\Windows\PowerShell\PSReadLine\ConsoleHost_history.txt" ascii nocase
        $s7 = "MrKaplan-Config.json" ascii nocase
        $s8 = "Invoke-StompFiles" ascii nocase
        $s9 = "Clear-Files" ascii nocase
        $s10 = "Clear-Registry" ascii nocase
        $s11 = "Invoke-RestoreEtw" ascii nocase
        $s12 = "Invoke-LogFileToStomp" ascii nocase
        $s13 = "Invoke-SuspendEtw" ascii nocase

    conditions:
        4 of $imports* and 3 of ($s*)
}