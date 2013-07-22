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
    # Due to dependency issues , different rpm pkgs are used in different platforms.
    # glib rpm package works in aix, without any dependency issues.
    when "aix"
      expect(shell_out("rpm -qa | grep glib").exitstatus).to eq(0)
    # hello rpm package works in centos, without any dependency issues.
    when "centos"
      expect(shell_out("rpm -qa | grep hello").exitstatus).to eq(0)
    end
  end

  def rpm_pkg_should_not_be_installed(resource)
    case ohai[:platform]
    when "aix"
      expect(shell_out("rpm -qa | grep glib").exitstatus).to eq(0)
    when "centos"
      expect(shell_out("rpm -qa | grep hello").exitstatus).to eq(1)
    end
  end

  before(:each) do
    case ohai[:platform]
    # Due to dependency issues , different rpm pkgs are used in different platforms.
    when "aix"
      FileUtils.cp 'spec/functional/assets/glib-1.2.10-2.aix4.3.ppc.rpm' , "/tmp/glib-1.2.10-2.aix4.3.ppc.rpm"
      @pkg_name = "glib"
      @pkg_path = "/tmp/glib-1.2.10-2.aix4.3.ppc.rpm"
    when "centos"
      FileUtils.cp 'spec/functional/assets/hello-2.8-1.el6.x86_64.rpm' , "/tmp/hello-2.8-1.el6.x86_64.rpm"
      @pkg_name = "hello"
      @pkg_path = "/tmp/hello-2.8-1.el6.x86_64.rpm"
    end
    @new_resource = Chef::Resource::RpmPackage.new(@pkg_name, run_context)
    @new_resource.source @pkg_path
  end

  after(:each) do
    FileUtils.rm @pkg_path
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
