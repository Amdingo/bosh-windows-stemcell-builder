# UPDATES
$ScriptDirectory = Split-Path $MyInvocation.MyCommand.Path -Parent
Import-Module (Join-Path "$ScriptDirectory" "PowershellUtils")

$UpdateLog="C:\update-logs.txt" # WARN: Change me!
$ProvisionScript="update-provisioner.ps1"

$RegistryKey = "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Run"
$RegistryEntry = "InstallWindowsUpdates"

function Add-AutoRun() {
    param([parameter(Mandatory=$true)] [String] $AdminPassword)

    # Enable auto-logon - required for auto-run
    REG ADD "HKEY_LOCAL_MACHINE\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Winlogon" /v AutoAdminLogon /d 1 /f
    REG ADD "HKEY_LOCAL_MACHINE\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Winlogon" /v DefaultUserName /d Administrator /f
    REG ADD "HKEY_LOCAL_MACHINE\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Winlogon" /v DefaultPassword /d "${AdminPassword}" /f

    $prop = (Get-ItemProperty $RegistryKey).$RegistryEntry
    $value = "C:\Windows\System32\WindowsPowerShell\v1.0\powershell.exe -File {0}\{1}" -f $ScriptDirectory, $ProvisionScript
    if ($prop -ne $value) {
        LogWrite $UpdateLog "Creating: restart registry with value ($value)"
        Set-ItemProperty -Path $RegistryKey -Name $RegistryEntry -Value $value
    } else {
        LogWrite $UpdateLog "Restart Registry Entry Exists Already"
    }
}

Add-AutoRun -AdminPassword "Password123!"

LogWrite $UpdateLog "InitialSetup: disabling service: WinRM"
Get-Service | Where-Object {$_.Name -eq "WinRM" } | Set-Service -StartupType Disabled

Restart-Computer -Force
