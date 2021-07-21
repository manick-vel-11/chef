#
# Author:: Adam Jacob (<adam@chef.io>)
# Copyright:: Copyright (c) Chef Software Inc.
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

require_relative "../package"
require_relative "deb"
require_relative "../../resource/apt_package"

class Chef
  class Provider
    class Package
      class Apt < Chef::Provider::Package
        include Chef::Provider::Package::Deb
        use_multipackage_api

        provides :package, platform_family: "debian", target_mode: true
        provides :apt_package, target_mode: true

        def initialize(new_resource, run_context)
          super
        end

        def load_current_resource
          @current_resource = Chef::Resource::AptPackage.new(new_resource.name)
          current_resource.package_name(new_resource.package_name)

          if source_files_exist?
            @candidate_version = get_candidate_version
            current_resource.package_name(get_package_name)
            # if the source file exists then our package_name is right
            current_resource.version(get_current_version_from(current_package_name_array))
          elsif !installing?
            # we can't do this if we're installing with no source, because our package_name
            # is probably not right.
            #
            # if we're removing or purging we don't use source, and our package_name must
            # be right so we can do this.
            #
            # we don't error here on the dpkg command since we'll handle the exception or
            # the why-run message in define_resource_requirements.
            current_resource.version(get_current_version_from(current_package_name_array))
          end

          current_resource
        end

        def define_resource_requirements
          super

          requirements.assert(:install, :upgrade) do |a|
            a.assertion { !resolved_source_array.compact.empty? }
            a.failure_message Chef::Exceptions::Package, "#{new_resource} the source property is required for action :install or :upgrade"
          end

          requirements.assert(:install, :upgrade) do |a|
            a.assertion { source_files_exist? }
            a.failure_message Chef::Exceptions::Package, "#{new_resource} source file(s) do not exist: #{missing_sources}"
            a.whyrun "Assuming they would have been previously created."
          end
        end

        def package_data
          @package_data ||= Hash.new do |hash, key|
            hash[key] = package_data_for(key)
          end
        end

        def current_package_name_array
          [ current_resource.package_name ].flatten
        end

        def candidate_version
          @candidate_version ||= get_candidate_version
        end

        def packages_all_locked?(names, versions)
          names.all? { |n| locked_packages.include? n }
        end

        def packages_all_unlocked?(names, versions)
          names.all? { |n| !locked_packages.include? n }
        end

        def locked_packages
          @locked_packages ||=
            begin
              locked = shell_out!("apt-mark", "showhold")
              locked.stdout.each_line.map(&:strip)
            end
        end

        def install_package(name, version)
          package_name = name.zip(version).map do |n, v|
            package_data[n][:virtual] ? n : "#{n}=#{v}"
          end
          dgrade = "--allow-downgrades" if supports_allow_downgrade? && allow_downgrade
          run_noninteractive("apt-get", "-q", "-y", dgrade, config_file_options, default_release_options, options, "install", package_name)
        end

        def upgrade_package(name, version)
          install_package(name, version)
        end

        def remove_package(name, version)
          package_name = name.map do |n|
            package_data[n][:virtual] ? resolve_virtual_package_name(n) : n
          end
          run_noninteractive("apt-get", "-q", "-y", options, "remove", package_name)
        end

        def purge_package(name, version)
          package_name = name.map do |n|
            package_data[n][:virtual] ? resolve_virtual_package_name(n) : n
          end
          run_noninteractive("apt-get", "-q", "-y", options, "purge", package_name)
        end

        def lock_package(name, version)
          run_noninteractive("apt-mark", options, "hold", name)
        end

        def unlock_package(name, version)
          run_noninteractive("apt-mark", options, "unhold", name)
        end

        private

        # @return [String] version of apt-get which is installed
        def apt_version
          @apt_version ||= shell_out("apt-get --version").stdout.match(/^apt (\S+)/)[1]
        end

        # @return [Boolean] if apt-get supports --allow-downgrades
        def supports_allow_downgrade?
          return @supports_allow_downgrade unless @supports_allow_downgrade.nil?

          @supports_allow_downgrade = ( version_compare(apt_version, "1.1.0") >= 0 )
        end

        # compare 2 versions to each other to see which is newer.
        # this differs from the standard package method because we
        # need to be able to parse debian version strings which contain
        # tildes which Gem cannot properly parse
        #
        # @return [Integer] 1 if v1 > v2. 0 if they're equal. -1 if v1 < v2
        def version_compare(v1, v2)
          if !shell_out("dpkg", "--compare-versions", v1.to_s, "gt", v2.to_s).error?
            1
          elsif !shell_out("dpkg", "--compare-versions", v1.to_s, "eq", v2.to_s).error?
            0
          else
            -1
          end
        end

        def default_release_options
          # Use apt::Default-Release option only if provider supports it
          if new_resource.respond_to?(:default_release) && new_resource.default_release
            [ "-o", "APT::Default-Release=#{new_resource.default_release}" ]
          end
        end

        def config_file_options
          # If the user has specified config file options previously, respect those.
          return if Array(options).any? { |opt| opt.include?("--force-conf") }

          # It doesn't make sense to install packages in a scenario that can
          # result in a prompt. Have users decide up-front whether they want to
          # forcibly overwrite the config file, otherwise preserve it.
          if new_resource.overwrite_config_files
            [ "-o", "Dpkg::Options::=--force-confnew" ]
          else
            [ "-o", "Dpkg::Options::=--force-confdef", "-o", "Dpkg::Options::=--force-confold" ]
          end
        end

        def resolve_package_versions(pkg)
          current_version = nil
          candidate_version = nil
          all_versions = []
          run_noninteractive("apt-cache", default_release_options, "policy", pkg).stdout.each_line do |line|
            case line
            when /^\s{2}Installed: (.+)$/
              current_version = ( $1 != "(none)" ) ? $1 : nil
              logger.trace("#{new_resource} installed version for #{pkg} is #{$1}")
            when /^\s{2}Candidate: (.+)$/
              candidate_version = ( $1 != "(none)" ) ? $1 : nil
              logger.trace("#{new_resource} candidate version for #{pkg} is #{$1}")
            when /\s+(?:\*\*\* )?(\S+) \d+/
              all_versions << $1
            end
          end
          # This is a bit ugly... really this whole provider needs
          # to be rewritten to use target_version_array and friends, but
          # for now this gets us moving
          idx = package_name_array.index(pkg)
          chosen_version =
            if idx
              user_ver = new_version_array[idx]
              if user_ver
                if all_versions.include?(user_ver)
                  user_ver
                else
                  logger.debug("User specified a version that's not available")
                  nil
                end
              else
                # user didn't specify a version, use candidate
                candidate_version
              end
            else
              # this probably means we're redirected from a virtual
              # package, so... just go with candidate version
              candidate_version
            end
          [ current_version, chosen_version ]
        end

        def resolve_virtual_package_name(pkg)
          showpkg = run_noninteractive("apt-cache", "showpkg", pkg).stdout
          partitions = showpkg.rpartition(/Reverse Provides: ?#{$/}/)
          return nil if partitions[0] == "" && partitions[1] == "" # not found in output

          set = partitions[2].lines.each_with_object(Set.new) do |line, acc|
            # there may be multiple reverse provides for a single package
            acc.add(line.split[0])
          end
          if set.size > 1
            raise Chef::Exceptions::Package, "#{new_resource.package_name} is a virtual package provided by multiple packages, you must explicitly select one"
          end

          set.to_a.first
        end

        def package_data_for(pkg)
          virtual           = false
          current_version   = nil
          candidate_version = nil

          current_version, candidate_version = resolve_package_versions(pkg)

          if candidate_version.nil?
            newpkg = resolve_virtual_package_name(pkg)

            if newpkg
              virtual = true
              logger.info("#{new_resource} is a virtual package, actually acting on package[#{newpkg}]")
              current_version, candidate_version = resolve_package_versions(newpkg)
            end
          end

          {
            current_version: current_version,
            candidate_version: candidate_version,
            virtual: virtual,
          }
        end

        # Helper to construct Hash of names-to-package-information.
        #
        # @return [Hash] Mapping of package names to package information
        def name_pkginfo
          @name_pkginfo ||=
            begin
              pkginfos = resolved_source_array.map do |src|
                logger.trace("#{new_resource} checking #{src} dpkg status")
                status = shell_out!("dpkg-deb", "-W", src)
                status.stdout
              end
              Hash[*package_name_array.zip(pkginfos).flatten]
            end
        end

        def name_candidate_version
          @name_candidate_version ||= name_pkginfo.transform_values { |v| v ? v.split("\t")[1]&.strip : nil }
        end

        def name_package_name
          @name_package_name ||= name_pkginfo.transform_values { |v| v ? v.split("\t")[0] : nil }
        end

        # Return candidate version array from pkg-deb -W against the source file(s).
        #
        # @return [Array] Array of candidate versions read from the source files
        def get_candidate_version
          package_name_array.map { |name| name_candidate_version[name] }
        end

        # Return package names from the candidate source file(s).
        #
        # @return [Array] Array of actual package names read from the source files
        def get_package_name
          package_name_array.map { |name| name_package_name[name] }
        end

        # Since upgrade just calls install, this is a helper to determine
        # if our action means that we'll be calling install_package.
        #
        # @return [Boolean] true if we're doing :install or :upgrade
        def installing?
          %i{install upgrade}.include?(action)
        end

        def read_current_version_of_package(package_name)
          logger.trace("#{new_resource} checking install state of #{package_name}")
          status = shell_out!("dpkg", "-s", package_name, returns: [0, 1])
          package_installed = false
          status.stdout.each_line do |line|
            case line
            when /^Status: deinstall ok config-files/.freeze
              # if we are 'purging' then we consider 'removed' to be 'installed'
              package_installed = true if action == :purge
            when /^Status: install ok installed/.freeze
              package_installed = true
            when /^Version: (.+)$/.freeze
              if package_installed
                logger.trace("#{new_resource} current version is #{$1}")
                return $1
              end
            end
          end
          nil
        end

        def get_current_version_from(array)
          array.map do |name|
            read_current_version_of_package(name)
          end
        end

        # Returns true if all sources exist.  Returns false if any do not, or if no
        # sources were specified.
        #
        # @return [Boolean] True if all sources exist
        def source_files_exist?
          resolved_source_array.all? { |s| s && ::File.exist?(s) }
        end

        # Helper to return all the names of the missing sources for error messages.
        #
        # @return [Array<String>] Array of missing sources
        def missing_sources
          resolved_source_array.select { |s| s.nil? || !::File.exist?(s) }
        end

      end
    end
  end
end
