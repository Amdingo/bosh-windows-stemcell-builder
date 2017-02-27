require 'stemcell/builder'

describe Stemcell::Builder do
  output_dir = ''

  around(:each) do |example|
    Dir.mktmpdir do |dir|
      output_dir = dir
      example.run
    end
  end

  describe 'GCP' do
    describe 'build' do
      it 'builds a stemcell tarball' do
        os = 'windows2012R2'
        version = '1234.0'
        agent_commit = 'some-agent-commit'
        config = 'some-packer-config'
        command = 'build'
        manifest_contents = 'manifest_contents'
        apply_spec_contents = 'apply_spec_contents'
        packer_vars = {some_var: 'some-value'}
        image_url = 'some-image-url'
        account_json = 'some-account-json'

        packer_config = double(:packer_config)
        allow(packer_config).to receive(:dump).and_return(config)
        allow(Packer::Config::Gcp).to receive(:new).with(account_json).and_return(packer_config)

        packer_runner = double(:packer_runner)
        allow(packer_runner).to receive(:run).with(command, packer_vars).and_return([0,",artifact,0,id,#{image_url}"])
        allow(Packer::Runner).to receive(:new).with(config).and_return(packer_runner)

        gcp_manifest = double(:gcp_manifest)
        allow(gcp_manifest).to receive(:dump).and_return(manifest_contents)
        gcp_apply = double(:gcp_apply)
        allow(gcp_apply).to receive(:dump).and_return(apply_spec_contents)

        allow(Stemcell::Manifest::Gcp).to receive(:new).with(version, os, image_url).and_return(gcp_manifest)
        allow(Stemcell::ApplySpec).to receive(:new).with(agent_commit).and_return(gcp_apply)
        allow(Stemcell::Packager).to receive(:package).with(iaas: 'gcp',
                                                            os: os,
                                                            is_light: true,
                                                            version: version,
                                                            image_path: '',
                                                            manifest: manifest_contents,
                                                            apply_spec: apply_spec_contents,
                                                            output_dir: output_dir
                                                           ).and_return('path-to-stemcell')

        stemcell_path = Stemcell::Builder::Gcp.new(
          os: os,
          output_dir: output_dir,
          version: version,
          agent_commit: agent_commit,
          packer_vars: packer_vars,
          account_json: account_json
        ).build
        expect(stemcell_path).to eq('path-to-stemcell')
      end
    end
  end
end
