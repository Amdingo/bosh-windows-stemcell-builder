Remove-Module -Name BOSH.CFCell -ErrorAction Ignore
Import-Module ./BOSH.CFCell.psm1

Remove-Module -Name BOSH.Utils -ErrorAction Ignore
Import-Module ../BOSH.Utils/BOSH.Utils.psm1

Describe "Protect-CFCell" {
    BeforeEach {
        $oldWinRMStatus = (Get-Service winrm).Status
        $oldWinRMStartMode = ( Get-Service winrm ).StartType

        { Set-Service -Name "winrm" -StartupType "Manual" } | Should Not Throw

        Start-Service winrm
    }

    AfterEach {
        if ($oldWinRMStatus -eq "Stopped") {
            { Stop-Service winrm } | Should Not Throw
        } else {
            { Set-Service -Name "winrm" -Status $oldWinRMStatus } | Should Not Throw
        }
        { Set-Service -Name "winrm" -StartupType $oldWinRMStartMode } | Should Not Throw
    }

    It "disables the RDP service and firewall rule" {
       Set-ItemProperty -Path "HKLM:\System\CurrentControlSet\Control\Terminal Server" -Name "fDenyTSConnections" -Value 0
       Get-NetFirewallRule -DisplayName "Remote Desktop*" | Set-NetFirewallRule -enabled true
       Get-Service "Termservice" | Set-Service -StartupType "Automatic"
       netstat /p tcp /a | findstr 3389 | Should Not BeNullOrEmpty

       Protect-CFCell

       Get-ItemProperty -Path "HKLM:\System\CurrentControlSet\Control\Terminal Server" | select -exp fDenyTSConnections | Should Be 1
       netstat /p tcp /a | findstr 3389 | Should BeNullOrEmpty
       Get-NetFirewallRule -DisplayName "Remote Desktop*" | ForEach { $_.enabled | Should be "False" }
       Get-Service "Termservice" | Select -exp starttype | Should Be "Disabled"
    }

    It "disables the services" {
       Get-Service | Where-Object {$_.Name -eq "WinRM" } | Set-Service -StartupType Automatic
       Get-Service | Where-Object {$_.Name -eq "W3Svc" } | Set-Service -StartupType Automatic
       Protect-CFCell
       (Get-Service | Where-Object {$_.Name -eq "WinRM" } ).StartType| Should be "Disabled"
       $w3svcStartType = (Get-Service | Where-Object {$_.Name -eq "W3Svc" } ).StartType
       "Disabled", $null -contains $w3svcStartType | Should Be $true
    }

    It "sets firewall rules" {
        Set-NetFirewallProfile -all -DefaultInboundAction Allow -DefaultOutboundAction Allow -AllowUnicastResponseToMulticast False -Enabled True
        get-firewall "public" | Should be "public,Allow,Allow"
        get-firewall "private" | Should be "private,Allow,Allow"
        get-firewall "domain" | Should be "domain,Allow,Allow"
        Protect-CFCell
        get-firewall "public" | Should be "public,Block,Allow"
        get-firewall "private" | Should be "private,Block,Allow"
        get-firewall "domain" | Should be "domain,Block,Allow"
    }
}

Describe "Remove-DockerPackage" {
    It "should bail out early if docker is already installed but we cannot test this either" {
        # Pester has issues mocking functions that use validateSet See: https://github.com/pester/Pester/issues/734
    }

    It "Is impossible to test this" {
        # Pester has issues mocking functions that use validateSet See: https://github.com/pester/Pester/issues/734
    }
}

Remove-Module -Name BOSH.CFCell -ErrorAction Ignore
Remove-Module -Name BOSH.Utils -ErrorAction Ignore
