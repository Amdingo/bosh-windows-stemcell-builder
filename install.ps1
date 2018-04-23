Add-Type -AssemblyName System.IO.Compression.FileSystem

function Unzip
{
    param([string]$zipfile, [string]$outpath)

    [System.IO.Compression.ZipFile]::ExtractToDirectory($zipfile, $outpath)
}

Unzip "${PSScriptRoot}\bosh-psmodules.zip"  "C:\Program Files\WindowsPowerShell\Modules"
powershell Install-CFFeatures
powershell Protect-CFCell

powershell Install-Agent -IaaS vsphere -agentZipPath "${PSScriptRoot}\agent.zip"
powershell Install-SSHD -SSHZipFile "${PSScriptRoot}\OpenSSH-Win64.zip"

Optimize-Disk
Compress-Disk

#Invoke-Sysprep -IaaS vsphere