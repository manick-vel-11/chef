#
# Author:: Prabhu Das (<prabhu.das@clogeny.com>)
# Copyright:: Copyright (c) 2013 Opscode, Inc.
# License:: Apache License, Version 2.0
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
require 'spec_helper'
require 'functional/resource/base'
require 'chef/resource/rpm_package'
require 'chef/mixin/shell_out'

describe Chef::Resource::RpmPackage do
  include Chef::Mixin::ShellOut

  def rpm_pkg_should_be_installed(resource)
    case ohai[:platform]

    when "aix"
      expect(shell_out("rpm -qa | grep a2ps").exitstatus).to eq(0)
    when "centos"
      expect(shell_out("rpm -qa | grep a2ps").exitstatus).to eq(0)
    end
  end


  def rpm_pkg_should_not_be_installed(resource)
    case ohai[:platform]

    when "aix"
      expect(shell_out("rpm -qa | grep a2ps").exitstatus).to eq(0)
    when "centos"
      expect(shell_out("rpm -qa | grep a2ps").exitstatus).to eq(1)
    end
  end

  before(:each) do
    FileUtils.cp 'spec/functional/assets/a2ps-4.14-10.1.el6.x86_64.rpm' , "/tmp/a2ps-4.14-10.1.el6.x86_64.rpm"
    @new_resource = Chef::Resource::RpmPackage.new("a2ps", run_context)
    @new_resource.source "/tmp/a2ps-4.14-10.1.el6.x86_64.rpm"
  end

  after(:each) do
    FileUtils.rm "/tmp/a2ps-4.14-10.1.el6.x86_64.rpm"
  end

  context "package install action" do
    it "- should create a package" do
      @new_resource.run_action(:install)
      rpm_pkg_should_be_installed(@new_resource)
    end

    after(:each) do
     @new_resource.run_action(:remove)
    end
  end

  context "package remove action" do
    before(:each) do
     @new_resource.run_action(:install)
    end

    it "- should remove an existing package" do
      @new_resource.run_action(:remove)
      rpm_pkg_should_not_be_installed(@new_resource)
    end
  end
end
