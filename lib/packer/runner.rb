require 'tempfile'
require 'json'
require 'English'
require 'open3'

module Packer
  class Runner
    class ErrorInvalidConfig < RuntimeError
    end

    def initialize(config)
      @config = config
    end

    def run(command, args={})
      puts "VVV CONFIG"
      puts @config
      puts "^^^ CONFIG"
      config_file = Tempfile.new('')
      config_file.write(@config)
      config_file.close

      args_combined = ''
      args.each do |name, value|
        args_combined += "-var \"#{name}=#{value}\""
      end

      packer_command = "packer #{command} -on-error abort -machine-readable #{args_combined} #{config_file.path}"
      puts packer_command

      Open3.popen2e(packer_command) do |stdin, out, wait_thr|
        yield(out) if block_given?
        return wait_thr.value
      end
    end
  end
end
