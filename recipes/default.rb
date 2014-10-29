#
# Cookbook Name:: azure
# Recipe:: default
#
# Copyright 2013, Example Com
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
# 
#     http://www.apache.org/licenses/LICENSE-2.0
# 
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
#
ark "nodejs" do
  url "http://nodejs.org/dist/v0.10.21/node-v0.10.21-linux-x64.tar.gz"
  version "0.10.21"
  path "/usr/local/nodejs"
  append_env_path true
end
# 
# # azure-cli
# # TODO: detect provider and make specific lwrps
azure_cli_path = "/node_modules/azure-cli"
execute "npm::azure-cli" do
  command "npm install azure-cli"
  not_if { File.exist?(File.join(azure_cli_path, "bin/azure")) }
end

ENV['PATH'] = ENV['PATH'] + ":" + "#{azure_cli_path}/bin"

file "/etc/profile.d/azure.env.sh" do
  owner "root"
  group "root"
  mode "0755"
  content "export PATH=#{azure_cli_path}/bin:$PATH"
end

# Gather information of which users still need azure account credentials set up
system_users_to_set_up = []

node['azure']['system_users_to_set_up'].each do |user|
  home = user == 'root' ? '/root' : "/home/#{user}"
  system_users_to_set_up.push user if ! ::File.exist? "#{home}/.azure/azureProfile.json"
end

# Only even bother startin the following steps if there is any user that needs
# setup
if !system_users_to_set_up.empty?
  azure_creds = Chef::EncryptedDataBagItem.load("azure", "publishsettings")

  azure_publish_settings = "/tmp/.azure.publishsettings"

  template azure_publish_settings do
    source "azure.publishsettings.erb"
    variables({
      subscription_id: azure_creds['subscription_id'],
      subscription_name: azure_creds['subscription_name'],
      subscription_certificate: azure_creds['subscription_certificate']
    })
  end

  system_users_to_set_up.each do |user|
    execute "azure::import" do
      user user
      environment ({ 'HOME' => (user == 'root' ? '/root' : "/home/#{user}") })
      command "azure account import #{azure_publish_settings}"
    end
  end

  file azure_publish_settings do
    action :delete
  end
end

