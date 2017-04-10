require 'rspec/core/rake_task'
require 'json'

namespace :build do
  desc 'Build AWS Stemcell'
  task :aws do
    aws_access_key = Stemcell::Builder::validate_env('AWS_ACCESS_KEY')
    aws_secret_key = Stemcell::Builder::validate_env('AWS_SECRET_KEY')
    os_version = Stemcell::Builder::validate_env('OS_VERSION')

    version_dir = Stemcell::Builder::validate_env_dir('VERSION_DIR')
    agent_dir = Stemcell::Builder::validate_env_dir('AGENT_DIR')
    base_amis_dir = Stemcell::Builder::validate_env_dir('BASE_AMIS_DIR')

    version = File.read(File.join(version_dir, 'number')).chomp
    agent_commit = File.read(File.join(agent_dir, 'sha')).chomp
    base_amis = JSON.parse(
      File.read(
        Dir.glob(File.join(base_amis_dir, 'base-amis-*.json'))[0]
      ).chomp
    )

    output_directory = File.absolute_path("bosh-windows-stemcell")
    FileUtils.mkdir_p(output_directory)

    aws_builder = Stemcell::Builder::Aws.new(
      agent_commit: agent_commit,
      amis: base_amis,
      aws_access_key: aws_access_key,
      aws_secret_key: aws_secret_key,
      os: os_version,
      output_directory: output_directory,
      packer_vars: {},
      version: version
    )

    aws_builder.build
  end
end
