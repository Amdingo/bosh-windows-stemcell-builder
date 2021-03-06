require 'net/http'
require 'uri'
require 'json'
require 'active_support'
require 'active_support/core_ext'
require 'active_model'
require 'azure_mgmt_resources'
require_relative '../../exec_command'

module Stemcell
  module Publisher
    class Azure
      include ActiveModel::Model

      attr_accessor :version, :sku, :azure_storage_account, :azure_published_storage_account,
        :azure_storage_access_key, :azure_published_storage_access_key, :azure_tenant_id, :azure_client_id,
        :azure_client_secret, :container_name, :container_path

      def print_publishing_instructions
        login_to_azure

        instructions = <<END
Please login to https://cloudpartner.azure.com
* Click "BOSH Azure Windows Stemcell"
* Click SKUs -> #{sku}
* Click "+ New VM image" at the bottom
* Input version "#{version}" and OS VHD URL "#{vhd_url}"
* Save and click Publish! Remember to click Go Live (in status tab) after it finishes!!
END
        puts instructions
      end

      def copy_vhd_to_published_storage_account
        login_to_azure
        azure_copy_command = "az storage blob copy start "\
          "--source-account-key \"#{azure_storage_access_key}\" "\
          "--source-account-name \"#{azure_storage_account}\" "\
          "--source-container \"system\" "\
          "--source-blob \"#{container_path}\" "\
          "--account-name \"#{azure_published_storage_account}\" "\
          "--destination-container \"system\" "\
          "--destination-blob \"#{container_path}\""
        puts "running azure copy"

        Executor.exec_command_no_output(azure_copy_command)
      end

      private
      def vhd_url
        retrieve_blob_url + "?" + create_azure_sas
      end

      def create_azure_sas
        now = Time.now.utc
        next_year = (now + 1.year).iso8601
        yesterday = (now - 1.day).iso8601
        create_sas_cmd = "az storage container generate-sas --name #{container_name} "\
          "--permissions rl "\
          "--account-name #{azure_published_storage_account} --account-key #{azure_published_storage_access_key} "\
          "--start #{yesterday} --expiry #{next_year}"

        Executor.exec_command(create_sas_cmd).strip.gsub('"','')
      end

      def retrieve_blob_url
        blob_url_command = "az storage blob url "\
        "--container-name #{container_name} "\
        "--name #{container_path} "\
        "--account-name #{azure_published_storage_account} --account-key #{azure_published_storage_access_key}"

        Executor.exec_command(blob_url_command).strip.gsub('"','')
      end

      def login_to_azure
        login_cmd = "az login --username #{azure_client_id} --password #{azure_client_secret} "\
          "--service-principal --tenant #{azure_tenant_id}"
        Executor.exec_command_no_output(login_cmd)
      end
    end
  end
end
