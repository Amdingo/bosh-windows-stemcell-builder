require 'rspec/core/rake_task'
require 'json'

require_relative '../../exec_command'

namespace :publish do
  desc 'Publish an image to the Azure marketplace'
  task :azure do
    PUBLISHER_URL = ENV['PUBLISHER_URL']
    SKU = ENV['SKU']
    API_KEY = ENV['API_KEY']

    container_root = File.expand_path('../../../../..', __FILE__)
    version = File.read(File.join(container_root, 'version', 'number')).chomp
    image_url = File.read(File.join(container_root, 'azure-base-vhd-uri', '*.txt')).chomp

    vm_to_add = {version: version, image_url: image_url}

    Stemcell::Publisher::Azure.publish(vm_to_add, API_KEY, PUBLISHER_URL, SKU)
  end
end
