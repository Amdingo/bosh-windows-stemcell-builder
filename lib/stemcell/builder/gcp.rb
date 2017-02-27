module Stemcell
  class Builder
    class Gcp < Base
      def initialize(account_json:, source_image:, **args)
        @account_json = account_json
        @project_id = JSON.parse(@account_json)['project_id']
        @source_image = source_image
        super(args)
      end

      def build
        image_url = run_packer
        manifest = Manifest::Gcp.new(@version, @os, image_url).dump
        super(iaas: 'gcp', is_light: true, image_path: '', manifest: manifest)
      end

      private
        def packer_config
          Packer::Config::Gcp.new(@account_json, @project_id, @source_image).dump
        end

        def run_packer
          image_name = nil
          Packer::Runner.new(packer_config).run('build', @packer_vars) do |stdout|
            stdout.each_line do |line|
              puts line
              image_name ||= parse_image_name(line)
            end
          end
          get_image_url(image_name)
        end

        def get_image_url(image_name)
          "https://www.googleapis.com/compute/v1/projects/#{@project_id}/global/images/#{image_name}"
        end

        def parse_image_name(line)
          if line.include?(",artifact,0,id,")
            return line.split(",").last.chomp
          end
        end
    end
  end
end
