module Stemcell
  class Builder
    class Aws < Base
      def initialize(amis:, aws_access_key:, aws_secret_key:, **args)
        @amis = amis
        @aws_access_key = aws_access_key
        @aws_secret_key = aws_secret_key
        super(args)
      end

      def build
        amis = run_packer
        puts "parsed amis: #{amis}"
        manifest = Manifest::Aws.new(@version, @os, amis).dump
        puts "manifest: #{manifest}"
        super(iaas: 'aws', is_light: true, image_path: '', manifest: manifest)
      end

      private

        def packer_config
          Packer::Config::Aws.new(@aws_access_key, @aws_secret_key, @amis).dump
        end

        def parse_packer_output(packer_output)
          amis = []
          packer_output.each_line do |line|
            if !(line.include?("secret_key") || line.include?("access_key"))
              puts line
            end
            ami = parse_ami(line)
            if !ami.nil?
              amis.push(ami)
            end
          end
          amis
        end

        def parse_ami(line)
          unless line.include?(",artifact,0,id,")
            return
          end

          region_id = line.split(",").last.split(":")
          return {'region'=> region_id[0].chomp, 'ami_id'=> region_id[1].chomp}
        end
    end
  end
end
