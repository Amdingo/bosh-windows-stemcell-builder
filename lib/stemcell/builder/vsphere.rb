require 'digest'
require 'tmpdir'
require 'zlib'
require 'nokogiri'
require 'fileutils'

module Stemcell
  class Builder
    class VSphereBase < Base
      def initialize(source_path:,
                     administrator_password:,
                     mem_size:,
                     num_vcpus:,
                     enable_rdp: false,
                     http_proxy:,
                     https_proxy:,
                     bypass_list:,
                     **args)
        @source_path = source_path
        @administrator_password = administrator_password
        @mem_size = mem_size
        @num_vcpus = num_vcpus
        @enable_rdp = enable_rdp
        @http_proxy = http_proxy
        @https_proxy = https_proxy
        @bypass_list = bypass_list
        super(args)
      end
    end

    class VSphereAddUpdates < VSphereBase
      def initialize(**args)
        args[:agent_commit] = ""
        args[:version] = ""
        super(args)
      end
      def build
        run_packer
      end

      private
      def packer_config
        Packer::Config::VSphereAddUpdates.new(
          administrator_password: @administrator_password,
          source_path: @source_path,
          output_directory: @output_directory,
          mem_size: @mem_size,
          num_vcpus: @num_vcpus,
          os: @os,
          http_proxy: @http_proxy,
          https_proxy: @https_proxy,
          bypass_list: @bypass_list
        ).dump
      end
    end

    class VSphere < VSphereBase
      def initialize(product_key:, owner:, organization:, new_password:, skip_windows_update:false,**args)
        @product_key = product_key
        @owner = owner
        @organization = organization
        @new_password = new_password
        @skip_windows_update = skip_windows_update
        super(args)
      end

      def build
        run_packer
        run_stembuild
      end

      def rename_stembuild_output
        # stembuild will output a tgz file with the trimmed down version, but we want to retain the original version in the filename
        new_filename = "bosh-stemcell-#{@version}-vsphere-esxi-#{@os}-go_agent.tgz"
        puts "renaming stemcell to #{new_filename}"
        FileUtils.mv Dir[File.join(@output_directory, "*.tgz")].first, File.join(@output_directory, new_filename)
      end

      private
      def packer_config
        Packer::Config::VSphere.new(
          administrator_password: @administrator_password,
          new_password: @new_password,
          source_path: @source_path,
          output_directory: @output_directory,
          mem_size: @mem_size,
          num_vcpus: @num_vcpus,
          product_key: @product_key,
          owner: @owner,
          organization: @organization,
          os: @os,
          enable_rdp: @enable_rdp,
          skip_windows_update: @skip_windows_update,
          http_proxy: @http_proxy,
          https_proxy: @https_proxy,
          bypass_list: @bypass_list
        ).dump
      end

      def self.find_file_by_extn(dir, extn)
        pattern = File.join(dir, "*.#{extn}").gsub('\\', '/')
        files = Dir.glob(pattern)
        if files.length == 0
          raise "No #{extn} files in directory: #{dir}"
        end
        if files.length > 1
          raise "Too many #{extn} files in directory: #{files}"
        end
        return files[0]
      end

      def find_file_by_extn(dir, extn)
        self.class.find_file_by_extn(dir, extn)
      end

      def run_stembuild
        vmdk_file = find_file_by_extn(@output_directory, "vmdk")
        if @os == 'windows2016'
          os_flag = '2016'
        else
          os_flag = '2012R2'
        end
        version_flag = Stemcell::Manifest::Base.strip_version_build_number(@version)
        cmd = "stembuild -vmdk \"#{vmdk_file}\" -v \"#{version_flag}\" -output \"#{@output_directory}\" -os #{os_flag}"
        puts "running stembuild command: [[ #{cmd} ]]"
        `#{cmd}`

        rename_stembuild_output
      end

      def find_vmx_file(dir)
        find_file_by_extn(dir, "vmx")
      end

      def gzip_file(name, output)
        Zlib::GzipWriter.open(output) do |gz|
          File.open(name) do |fp|
            while chunk = fp.read(32 * 1024) do
              gz.write chunk
            end
          end
          gz.close
        end
      end

      def removeNIC(ova_file_name)
        Stemcell::Packager.removeNIC(ova_file_name)
      end

      def create_image(vmx_dir)
        sha1_sum=''
        image_file = File.join(vmx_dir, 'image')
        Dir.mktmpdir do |tmpdir|
          vmx_file = find_vmx_file(vmx_dir)
          ova_file = File.join(tmpdir, 'image.ova')
          exec_command("ovftool '#{vmx_file}' '#{ova_file}'")
          removeNIC(ova_file)
          gzip_file(ova_file, image_file)
          sha1_sum = Digest::SHA1.file(image_file).hexdigest
        end
        [image_file, sha1_sum]
      end
    end

    class VCenter < VSphere
      def build
        run_packer
        export_vmdk
        run_stembuild
      end

      private
      # a template needs to be availeble of the windows2012 first with winrm enabled
      def packer_config
        JSON.dump(JSON.parse(super).tap do |config|
          config['builders'] = [
            {
              'type' => 'vsphere',
              'vcenter_server' => Stemcell::Builder::validate_env('VCENTER_SERVER'),
              'username' => Stemcell::Builder::validate_env('VCENTER_USERNAME'),
              'password' => Stemcell::Builder::validate_env('VCENTER_PASSWORD'),
              'insecure_connection' => true,
              'template' => Stemcell::Builder::validate_env('BASE_TEMPLATE'),
              'folder' => Stemcell::Builder::validate_env('VCENTER_VM_FOLDER'),
              'vm_name' => 'packer-vcenter',
              'host' => Stemcell::Builder::validate_env('VCENTER_HOST'),
              'datastore' => Stemcell::Builder::validate_env('VCENTER_DATASTORE'),
              'resource_pool' => '',
              'ssh_username' => 'Administrator',
              'ssh_password' => Stemcell::Builder::validate_env('ADMINISTRATOR_PASSWORD'),
              'communicator' => 'winrm',
              'winrm_username' => 'Administrator',
              'winrm_password' => Stemcell::Builder::validate_env('ADMINISTRATOR_PASSWORD'),
              'winrm_timeout' => '3h',
              'winrm_insecure' => true,
              'CPUs' => Stemcell::Builder::validate_env('NUM_VCPUS', '4'),
              'RAM'  => Stemcell::Builder::validate_env('MEM_SIZE', '4096'),
              'datacenter' => Stemcell::Builder::validate_env('VCENTER_DATACENTER')
            }
          ]
        end)
      end

      $dir = '/root' # Dir.pwd
      # we can change this when govmami has the export feature https://github.com/vmware/govmomi/pull/813 or maby intergrate
      # in vpshere plugin see https://github.com/jetbrains-infra/packer-builder-vsphere/issues/34
      def export_vmdk
        folder = validate_env('VCENTER_VM_FOLDER')
        host_folder = validate_env('VCENTER_HOST_FOLDER')
        server = validate_env('VCENTER_SERVER')
        username = validate_env('VCENTER_USERNAME')
        password = validate_env('VCENTER_PASSWORD')
        cmd = "ovftool --noSSLVerify --machineOutput \"vi://#{username}:#{password}@#{server}/#{host_folder}/vm/#{folder}/packer-vcenter/\" #{$dir}/"
        puts cmd
        Open3.popen3(cmd) do |stdin, stdout, stderr, wait_thr|
          while line=stdout.gets || line=stderr.gets do
            puts(line)
          end
        end
      end

      # produces tgz and needs to be uploaded to s3
      def run_stembuild
        vmdk_file = find_file_by_extn(@output_directory, 'vmdk')
        cmd = "stembuild -vmdk \"#{vmdk_file}\" -v \"#{Stemcell::Manifest::Base.strip_version_build_number(@version)}.#{Time.now.getutc.to_i}\" -output \"#{@output_directory}\""
        puts "running stembuild command: [[ #{cmd} ]]"
        `#{cmd}`
      end

      administrator_password = validate_env('ADMINISTRATOR_PASSWORD')

      # version should be agent/p_modules number from github
      # windows update versioning? how do we check/compare?
      versionfile = File.join(Dir.pwd, 'build', 'version')
      version = IO.read(versionfile).chomp

      sourcedir = '/root/packer-vcenter/'#File.join(Dir.pwd, 'packer-vcenter')

      vcenter = VCenter.new(
        mem_size: ENV.fetch('MEM_SIZE', '4096'),
        num_vcpus: ENV.fetch('NUM_VCPUS', '4'),
        source_path: sourcedir,
        agent_commit: 'bar',
        administrator_password: administrator_password,
        new_password: ENV.fetch('NEW_PASSWORD', administrator_password),
        product_key: ENV['PRODUCT_KEY'],
        owner: validate_env('OWNER'),
        organization: validate_env('ORGANIZATION'),
        os: validate_env('OS_VERSION'),
        output_directory: sourcedir,
        packer_vars: {},
        version: version,
        enable_rdp: ENV['ENABLE_RDP'] ? (ENV['ENABLE_RDP'].downcase == 'true') : false,
        enable_kms: ENV['ENABLE_KMS'] ? (ENV['ENABLE_KMS'].downcase == 'true') : false,
        kms_host: ENV.fetch('KMS_HOST', ''),
        skip_windows_update: ENV['SKIP_WINDOWS_UPDATE']
      )

      vcenter.build
    end
  end
end
