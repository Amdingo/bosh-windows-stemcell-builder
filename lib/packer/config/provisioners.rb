require 'securerandom'

module Packer
  module Config
    class Provisioners

      def self.powershell_provisioner(command)
        {
          'type' => 'powershell',
          'inline' => [
            '$ErrorActionPreference = "Stop";',
            'trap { $host.SetShouldExit(1) }',
            command
          ]
        }
      end

      BOSH_PSMODULES = [
        {
          'type' => 'file',
          'source' => 'build/bosh-psmodules.zip',
          'destination' => 'C:\\provision\\bosh-psmodules.zip'
        }, {
          'type' => 'powershell',
          'scripts' => ['scripts/install-bosh-psmodules.ps1']
        }
      ].freeze
      NEW_PROVISIONER = powershell_provisioner('New-Provisioner')
      INSTALL_KB4056898 = {
        'type' => 'windows-restart',
        'restart_command' => "powershell.exe -Command Install-KB4056898",
        'restart_timeout' => '1h'
      }
      INSTALL_CF_FEATURES_2016  = {
        'type' => 'windows-restart',
        'restart_command' => "powershell.exe -Command Install-CFFeatures",
        'restart_timeout' => '1h'
      }
      WAIT_AND_RESTART = {
        'type' => 'windows-restart',
        'restart_command' => 'powershell.exe -Command Start-Sleep -Seconds 900; Restart-Computer -Force',
        'restart_timeout' => '1h'
      }
      INSTALL_CF_FEATURES_2012 = powershell_provisioner('Install-CFFeatures')
      PROTECT_CF_CELL = powershell_provisioner('Protect-CFCell')
      OPTIMIZE_DISK = powershell_provisioner('Optimize-Disk')
      COMPRESS_DISK = powershell_provisioner('Compress-Disk')
      CLEAR_PROVISIONER = powershell_provisioner('Clear-Provisioner')
      GET_LOG = powershell_provisioner('Get-Log')
      CLEAR_PROXY_SETTINGS = powershell_provisioner('Clear-ProxySettings')

      def self.setup_proxy_settings(http_proxy, https_proxy, bypass_list)
        return powershell_provisioner("Set-ProxySettings #{http_proxy} #{https_proxy} #{bypass_list}")
      end

      def self.install_windows_updates
        password = SecureRandom.hex(10)+"!"
        return [
          powershell_provisioner("Add-Account -User Provisioner -Password #{password}"),
          powershell_provisioner("Register-WindowsUpdatesTask"),
          {
            'type' => 'windows-restart',
            'restart_command' => "powershell.exe -Command Wait-WindowsUpdates -Password #{password} -User Provisioner",
            'restart_timeout' => '12h'
          },
          powershell_provisioner("Unregister-WindowsUpdatesTask"),
          powershell_provisioner("Remove-Account -User Provisioner"),
          powershell_provisioner("Test-InstalledUpdates")
        ]
      end

      def self.download_windows_updates(dest)
        return [
          powershell_provisioner('Get-Hotfix | Out-File -FilePath "C:\\updates.txt" -Encoding ASCII'),
          {
            'type' => 'file',
            'source' => 'C:\\updates.txt',
            'destination' => File.join(dest, 'updates.txt'),
            'direction' => 'download'
          }
        ]
      end

      def self.install_agent(iaas)
        return [
          {
            'type' => 'file',
            'source' => 'build/agent.zip',
            'destination' => 'C:\\provision\\agent.zip'
          },
          powershell_provisioner("Install-Agent -IaaS #{iaas} -agentZipPath 'C:\\provision\\agent.zip'")
        ]
      end

      INSTALL_SSHD = [
        {
          'type' => 'file',
          'source' => '../sshd/OpenSSH-Win64.zip',
          'destination' => 'C:\\provision\\OpenSSH-Win64.zip'
        },
        powershell_provisioner("Install-SSHD -SSHZipFile 'C:\\provision\\OpenSSH-Win64.zip'")
      ]

      def self.lgpo_exe
        {
          'type' => 'file',
          'source' => File.join(Stemcell::Builder::validate_env_dir('STEMCELL_DEPS_DIR'), 'lgpo', 'LGPO.exe'),
          'destination' => 'C:\\windows\\LGPO.exe'
        }.freeze
      end

      def self.git_exe
        return [
            {
                'type' => 'file',
                'source' => File.join(Stemcell::Builder::validate_env_dir('STEMCELL_DEPS_DIR'), 'git', 'Git-2.16.2-64-bit.exe'),
                'destination' => 'C:\\provision\\Git-2.16.2-64-bit.exe'
            },
            powershell_provisioner( "C:\\provision\\Git-2.16.2-64-bit.exe /sp /silent")
        ]
      end

      def self.sysprep_shutdown(iaas, os)
        return [powershell_provisioner("Invoke-Sysprep -IaaS #{iaas} -OsVersion #{os}")]
      end
    end
  end
end
