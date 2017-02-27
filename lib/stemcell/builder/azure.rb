module Stemcell
  class Builder
    class Azure < Base
      def build
        image_path = get_image
        sha = Digest::SHA1.file(image_path).hexdigest
        manifest = Manifest::Azure.new('bosh-azure-stemcell-name', @version, sha, @os).dump
        super(iaas: 'azure', is_light: false, image_path: image_path, manifest: manifest)
      end

      private
        def packer_config
          Packer::Config::Azure.new().dump
        end

        def get_image
          disk_uri = nil
          Packer::Runner.new(packer_config).run('build', @packer_vars) do |stdout|
            stdout.each_line do |line|
              puts line
              disk_uri ||= parse_disk_uri(line)
            end
          end
          download_disk(disk_uri)
          Packager.package_image(image_path: "#{@output_dir}/root.vhd", archive: true, output_dir: @output_dir)
        end

        def parse_disk_uri(line)
          unless line.include?("azure-arm,artifact,0") and line.include?("OSDiskUriReadOnlySas:")
            return
          end
          (line.split '\n').select do |s|
            s.start_with?("OSDiskUriReadOnlySas: ")
          end.first.gsub("OSDiskUriReadOnlySas: ", "")
        end

        def download_disk(disk_uri)
          exec_command("curl -s -o '#{@output_dir}/root.vhd' '#{disk_uri}'")
        end
    end
  end
end
