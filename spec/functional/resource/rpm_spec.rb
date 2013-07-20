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

describe Chef::Resource::RpmPackage do
  OHAI_SYSTEM = Ohai::System.new
  OHAI_SYSTEM.require_plugin("os")
  OHAI_SYSTEM.require_plugin("platform")

  def rpm_pkg_binary_file_exist(resource)
    case OHAI_SYSTEM[:platform]

    when "aix"

    when "centos"
      pkg_binary = "/usr/bin/a2ps"
      ::File.exists?(pkg_binary)
    end
  end

  def rpm_pkg_binary_file_does_not_exist(resource)
   case OHAI_SYSTEM[:platform]

    when "aix"

    when "centos"
      pkg_binary = "/usr/bin/a2ps"
      !::File.exists?(pkg_binary)
    end
  end

  before(:each) do
    @node = Chef::Node.new
    @events = Chef::EventDispatch::Dispatcher.new
    @run_context = Chef::RunContext.new(@node, {}, @events)
    @new_resource = Chef::Resource::Package.new("a2ps")
    @new_resource.source "/tmp/a2ps-4.14-10.1.el6.x86_64.rpm"
    @provider = Chef::Provider::Package::Rpm.new(@new_resource, @run_context)
  end

  context "package install action" do
    it "- should create a package" do
      @provider.run_action(:install)
      expect{rpm_pkg_binary_file_exist(@new_resource)}.to be_true
    end

    after(:each) do
     @provider.run_action(:remove)
    end
  end

  context "package remove action" do
    before(:each) do
     @provider.run_action(:install)
    end

    it "- should remove an existing package" do
      @provider.run_action(:remove)
      expect{rpm_pkg_binary_file_does_not_exist(@new_resource)}.to be_true
    end
  end
end
