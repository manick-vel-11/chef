#
# Author:: Nimisha Sharad (<nimisha.sharad@msystechnologies.com>)
# Copyright:: Copyright 2008-2018, Chef Software Inc.
# License:: Apache License, Version 2.0
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#    http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
#

require "chef/mixin/shell_out"
require "rexml/document"
require "iso8601"
require "chef/mixin/powershell_out"
require "chef/provider"
require "win32/taskscheduler"

class Chef
  class Provider
    class WindowsTask < Chef::Provider
      include Chef::Mixin::ShellOut
      include Chef::Mixin::PowershellOut
      include Win32

      provides :windows_task

      MONTHS = {
        :JAN => TaskScheduler::JANUARY,
        :FEB => TaskScheduler::FEBRUARY,
        :MAR => TaskScheduler::MARCH,
        :APR => TaskScheduler::APRIL,
        :MAY => TaskScheduler::MAY,
        :JUN => TaskScheduler::JUNE,
        :JUL => TaskScheduler::JULY,
        :AUG => TaskScheduler::AUGUST,
        :SEP => TaskScheduler::SEPTEMBER,
        :OCT => TaskScheduler::OCTOBER,
        :NOV => TaskScheduler::NOVEMBER,
        :DEC => TaskScheduler::DECEMBER
      }

      DAYS_OF_WEEK = { :MON => TaskScheduler::MONDAY,
                       :TUE => TaskScheduler::TUESDAY,
                       :WED => TaskScheduler::WEDNESDAY,
                       :THU => TaskScheduler::THURSDAY,
                       :FRI => TaskScheduler::FRIDAY,
                       :SAT => TaskScheduler::SATURDAY,
                       :SUN => TaskScheduler::SUNDAY }

      WEEKS_OF_MONTH = {
        :FIRST => TaskScheduler::FIRST_WEEK,
        :SECOND => TaskScheduler::SECOND_WEEK,
        :THIRD => TaskScheduler::THIRD_WEEK,
        :FOURTH => TaskScheduler::FOURTH_WEEK,
        :LAST => TaskScheduler::LAST_WEEK
      }

      DAYS_OF_MONTH = {
        1 => TaskScheduler::TASK_FIRST,
        2 => TaskScheduler::TASK_SECOND,
        3 => TaskScheduler::TASK_THIRD,
        4 => TaskScheduler::TASK_FOURTH,
        5 => TaskScheduler::TASK_FIFTH,
        6 => TaskScheduler::TASK_SIXTH,
        7 => TaskScheduler::TASK_SEVENTH,
        8 => TaskScheduler::TASK_EIGHTH,
        9 => TaskScheduler::TASK_NINETH,
        10 => TaskScheduler::TASK_TENTH,
        11 => TaskScheduler::TASK_ELEVENTH,
        12 => TaskScheduler::TASK_TWELFTH,
        13 => TaskScheduler::TASK_THIRTEENTH,
        14 => TaskScheduler::TASK_FOURTEENTH,
        15 => TaskScheduler::TASK_FIFTEENTH,
        16 => TaskScheduler::TASK_SIXTEENTH,
        17 => TaskScheduler::TASK_SEVENTEENTH,
        18 => TaskScheduler::TASK_EIGHTEENTH,
        19 => TaskScheduler::TASK_NINETEENTH,
        20 => TaskScheduler::TASK_TWENTIETH,
        21 => TaskScheduler::TASK_TWENTY_FIRST,
        22 => TaskScheduler::TASK_TWENTY_SECOND,
        23 => TaskScheduler::TASK_TWENTY_THIRD,
        24 => TaskScheduler::TASK_TWENTY_FOURTH,
        25 => TaskScheduler::TASK_TWENTY_FIFTH,
        26 => TaskScheduler::TASK_TWENTY_SIXTH,
        27 => TaskScheduler::TASK_TWENTY_SEVENTH,
        28 => TaskScheduler::TASK_TWENTY_EIGHTH,
        29 => TaskScheduler::TASK_TWENTY_NINTH,
        30 => TaskScheduler::TASK_THIRTYETH,
        31 => TaskScheduler::TASK_THIRTY_FIRST,
        :last => TaskScheduler::TASK_LAST
      }

      def load_current_resource
        @current_resource = Chef::Resource::WindowsTask.new(new_resource.name)
        task = TaskScheduler.new
        if task.exists?(new_resource.name)
          @current_resource.exists = true
          task.get_task(new_resource.name)
          @current_resource.task = task
          pathed_task_name = new_resource.task_name.start_with?('\\') ? new_resource.task_name : "\\#{new_resource.task_name}"
          @current_resource.task_name(pathed_task_name)
        else
          @current_resource.exists = false
        end
        @current_resource
      end

      def action_create
        if current_resource.exists
          Chef::Log.debug "#{new_resource} task exist."
          unless (task_needs_update?(current_resource.task) || new_resource.force)
            Chef::Log.info "#{new_resource} task does not need updating and force is not specified - nothing to do"
            return
          end

          # if start_day and start_time is not set by user current date and time will be set while updating any property
          set_start_day_and_time
          update_task(current_resource.task)
        else
          basic_validation
          set_start_day_and_time
          task = TaskScheduler.new
          task.new_work_item(new_resource.name, trigger)
          task.application_name = new_resource.command
          task.configure_settings(config_settings)
          task.configure_principals(principal_settings)
          task.set_account_information(new_resource.user, new_resource.password)
          converge_by("#{new_resource} task created") do
            task.activate(new_resource.name)
          end
        end
      end

      def action_run
        if current_resource.exists
          Chef::Log.debug "#{new_resource} task exists"
          if current_resource.task.status == "running"
            Chef::Log.info "#{new_resource} task is currently running, skipping run"
          else
            converge_by("run scheduled task #{new_resource}") do
              current_resource.task.run
            end
          end
        else
          Chef::Log.warn "#{new_resource} task does not exist - nothing to do"
        end
      end

      def action_delete
        if current_resource.exists
          Chef::Log.debug "#{new_resource} task exists"
          converge_by("delete scheduled task #{new_resource}") do
            ts = TaskScheduler.new
            ts.delete(current_resource.name)
            # always need to force deletion
            # run_schtasks "DELETE", "F" => ""
          end
        else
          Chef::Log.warn "#{new_resource} task does not exist - nothing to do"
        end
      end

      def action_end
        if current_resource.exists
          Chef::Log.debug "#{new_resource} task exists"
          if current_resource.task.status != "running"
            Chef::Log.debug "#{new_resource} is not running - nothing to do"
          else
            converge_by("#{new_resource} task ended") do
              current_resource.task.stop
            end
          end
        else
          Chef::Log.warn "#{new_resource} task does not exist - nothing to do"
        end
      end

      def action_enable
        if current_resource.exists
          Chef::Log.debug "#{new_resource} task exists"
          if current_resource.task.status == "not scheduled"
            converge_by("#{new_resource} task enabled") do
              #TODO wind32-taskscheduler currently not having any method to handle this so using schtasks.exe here
              run_schtasks "CHANGE", "ENABLE" => ""
            end
          else
            Chef::Log.debug "#{new_resource} already enabled - nothing to do"
          end
        else
          Chef::Log.fatal "#{new_resource} task does not exist - nothing to do"
          raise Errno::ENOENT, "#{new_resource}: task does not exist, cannot enable"
        end
      end

      def action_disable
        if current_resource.exists
          Chef::Log.info "#{new_resource} task exists"
          if ["ready", "running"].include?(current_resource.task.status)
            converge_by("#{new_resource} task disabled") do
              #TODO: in win32-taskscheduler there is no method whcih disbales the task so currently calling disable with schtasks.exe
              run_schtasks "CHANGE", "DISABLE" => ""
            end
          else
            Chef::Log.warn "#{new_resource} already disabled - nothing to do"
          end
        else
          Chef::Log.warn "#{new_resource} task does not exist - nothing to do"
        end
      end

      private

      def set_start_day_and_time
        new_resource.start_day = Time.now.strftime("%m/%d/%Y") unless new_resource.start_day
        new_resource.start_time = Time.now.strftime("%H:%M") unless new_resource.start_time
      end

      def update_task(task)
        converge_by("#{new_resource} task updated") do
          task.application_name = new_resource.command
          task.trigger = trigger
          task.configure_settings(config_settings)
          task.configure_principals(principal_settings)
        end
      end

      def trigger
        date = new_resource.start_day.split('/') if new_resource.start_day
        time = new_resource.start_time.split(':') if new_resource.start_time
        #TODO currently end_month, end_year and end_year needs to be set to 0. If not set win32-taskscheduler throwing nil into integer error.
        trigger_hash = {
          start_year: date.nil? ? 0 : date[2].to_i,
          start_month: date.nil? ? 0 : date[0].to_i,
          start_day: date.nil? ? 0 : date[1].to_i,
          start_hour: time.nil? ? 0 : time[0].to_i,
          start_minute: time.nil? ? 0 : time[1].to_i,
          end_month: 0,
          end_day: 0,
          end_year: 0,
          trigger_type: trigger_type,
          type: type,
          random_minutes_interval: new_resource.random_delay
        }
        if new_resource.frequency == :minute
          trigger_hash[:minutes_interval] = new_resource.frequency_modifier
        end

        if new_resource.frequency == :hourly
          minutes = convert_in_minutes(new_resource.frequency_modifier.to_i)
          trigger_hash[:minutes_interval] = minutes
        end

        if new_resource.minutes_interval
          trigger_hash[:minutes_interval] = new_resource.minutes_interval
        end

        if new_resource.minutes_duration
          trigger_hash[:minutes_duration] = new_resource.minutes_duration
        end

        trigger_hash
      end

      def convert_in_minutes(frequency_modifier)
        frequency_modifier * 60
      end

      #TODO : Try to optimize this method
      # known issue : Since start_day and time is not mandatory while updating weekly frequency for which start_day is not mentioned by user idempotency
      # is not gettting maintained as new_resource.start_day is nil and we fetch the day of week from start_day to set and its currently coming as nil and don't match with current_task
      def task_needs_update?(task)
        flag = false
        current_task_trigger = task.trigger(0)
        new_task_trigger = trigger

        if new_resource.frequency == :on_idle
          # Converting here new_resource.idle_time in seconds to compare
          flag =  true if ISO8601::Duration.new(task.idle_settings[:idle_duration]) != ISO8601::Duration.new(new_resource.idle_time * 60)
        end

        unless new_resource.execution_time_limit.nil?
          flag = true if ISO8601::Duration.new(task.execution_time_limit) != ISO8601::Duration.new(new_resource.execution_time_limit * 60)
        end

        # if trigger not found updating the task to add the trigger
        if current_task_trigger.nil?
          flag = true
        else
          flag = true if start_day_updated?(current_task_trigger, new_task_trigger) == true ||
          start_time_updated?(current_task_trigger, new_task_trigger) == true ||
          current_task_trigger[:trigger_type] != new_task_trigger[:trigger_type] ||
          current_task_trigger[:type] != new_task_trigger[:type] ||
          current_task_trigger[:random_minutes_interval].to_i != new_task_trigger[:random_minutes_interval].to_i ||
          current_task_trigger[:minutes_interval] != new_task_trigger[:minutes_interval] ||
          task.account_information != new_resource.user ||
          task.application_name != new_resource.command ||
          task.principals[:run_level] != run_level
        end

        flag
      end

      def start_day_updated?(current_task_trigger, new_task_trigger)
        ( new_resource.start_day && (current_task_trigger[:start_year].to_i != new_task_trigger[:start_year] ||
                  current_task_trigger[:start_month].to_i != new_task_trigger[:start_month] ||
                  current_task_trigger[:start_day].to_i != new_task_trigger[:start_day]) )
      end

      def start_time_updated?(current_task_trigger, new_task_trigger)
        ( new_resource.start_time && ( current_task_trigger[:start_hour].to_i != new_task_trigger[:start_hour] ||
          current_task_trigger[:start_minute].to_i != new_task_trigger[:start_minute] ) )
      end

      def trigger_type
        case new_resource.frequency
          when :once, :minute, :hourly
            TaskScheduler::ONCE
          when :daily
            TaskScheduler::DAILY
          when :weekly
            TaskScheduler::WEEKLY
          when :monthly
            # If frequency modifier is set with frequency :monthly we are setting taskscheduler as monthlydow
            # Ref https://msdn.microsoft.com/en-us/library/windows/desktop/aa382061(v=vs.85).aspx
            if new_resource.frequency_modifier != 1
              TaskScheduler::MONTHLYDOW
            else
              TaskScheduler::MONTHLYDATE
            end
          when :on_idle
            TaskScheduler::ON_IDLE
          when :onstart
            TaskScheduler::AT_SYSTEMSTART
          when :on_logon
            TaskScheduler::AT_LOGON
          else
            #TODO
          end
      end

      def type
        case trigger_type
        when TaskScheduler::ONCE
          { once: nil }
        when TaskScheduler::DAILY
          { days_interval: new_resource.frequency_modifier }
        when TaskScheduler::WEEKLY
          { weeks_interval: new_resource.frequency_modifier, days_of_week: days_of_week }
        when TaskScheduler::MONTHLYDATE
          { months: months_of_year, days: days_of_month }
        when TaskScheduler::MONTHLYDOW
          { months: months_of_year, days_of_week: days_of_week, weeks_of_month: weeks_of_month }
        when TaskScheduler::ON_IDLE
          # TODO: handle option for this trigger
        when TaskScheduler::AT_LOGON
          # TODO: handle option for this trigger
        when TaskScheduler::AT_SYSTEMSTART
          # TODO: handle option for this trigger
        end
      end

      # NOTE: Idempotency for weeks_of_month is not getting maintained with `last` week since win32-taskscheduler library returns wrong value which we use for comparision
      def weeks_of_month
        weeks_of_month = []
        if new_resource.frequency_modifier
          weeks = new_resource.frequency_modifier.split(",")
          weeks.each do |week|
            weeks_of_month << WEEKS_OF_MONTH[week.strip.upcase.to_sym]
          end
          weeks_of_month = weeks_of_month.size > 1 ? weeks_of_month.inject(:|) : weeks_of_month[0]
        end
        weeks_of_month
      end

      # known issue : setting days of month last does not work coming acorss
      # error WIN32OLERuntimeError: (in setting property `DaysOfMonth': )
        # OLE error code:0 in <Unknown>
        #   <No Description>
        # HRESULT error code:0x8002000a
        #   Out of present range.
      def days_of_month
        days_of_month = []
        if new_resource.day
          if (1..31).to_a.push("last").map(&:to_s).include?(new_resource.day[0].downcase)
            days = new_resource.day.split(",")
            days.each do |day|
              if day.strip.downcase == "last"
                days_of_month << DAYS_OF_MONTH[day.strip.downcase.to_sym]
              else
                days_of_month << DAYS_OF_MONTH[day.to_i]
              end
            end
            days_of_month = days_of_month.size > 1 ? days_of_month.inject(:|) : days_of_month[0]
          end
        else
          days_of_month = DAYS_OF_MONTH[1]
        end
        days_of_month
      end

      def days_of_week
        if new_resource.day
          days = new_resource.day.split(',').map(&:upcase)
          week_days = []
          if days.size > 1
            days.each do |day|
              day = day.strip.to_sym
              week_days << DAYS_OF_WEEK[day]
            end
            week_days = week_days.inject(:|)
          else
            DAYS_OF_WEEK[days[0].to_sym]
          end
        else
          day = get_day(new_resource.start_day).to_sym if new_resource.start_day
          DAYS_OF_WEEK[day]
        end
      end

      def months_of_year
        months_of_year = []
        if new_resource.months
          months = new_resource.months.split(',').map(&:upcase)
          if months.size > 1
            months.each do |month|
              month = month.strip.to_sym
              months_of_year << MONTHS[month]
            end
            months_of_year = months_of_year.inject(:|)
          else
            months_of_year = MONTHS[new_resource.months.upcase.to_sym]
          end
        else
          months = MONTHS.each do |key, value|
            months_of_year << MONTHS[key]
          end
          months_of_year = months_of_year.inject(:|)
        end
        months_of_year
      end

      def run_level
        case new_resource.run_level
        when :highest
          TaskScheduler::TASK_RUNLEVEL_HIGHEST
        when :limited
          TaskScheduler::TASK_RUNLEVEL_LUA
        end
      end

      #TODO: while creating the configuration settings win32-taskscheduler it accepts execution time limit values in ISO8601 formata
      def config_settings
        settings = {
          execution_time_limit: new_resource.execution_time_limit,
          enabled: true
        }
        settings[:idle_duration] = new_resource.idle_time if new_resource.idle_time
        settings[:run_only_if_idle] = true if new_resource.idle_time
        settings
      end

      def principal_settings
        settings = { run_level: run_level }
      end

      # This method checks if task and command attributes exist since those two are mandatory attributes to create a schedules task.
      def basic_validation
        validate = []
        validate << "Command" if new_resource.command.nil? || new_resource.command.empty?
        validate << "Task Name" if new_resource.task_name.nil? || new_resource.task_name.empty?
        return true if validate.empty?
        raise Chef::Exceptions::ValidationFailed.new "Value for '#{validate.join(', ')}' option cannot be empty"
      end

      # rubocop:disable Style/StringLiteralsInInterpolation
      def run_schtasks(task_action, options = {})
        cmd = "schtasks /#{task_action} /TN \"#{new_resource.task_name}\" "
        options.each_key do |option|
          unless option == "TR"
            cmd += "/#{option} "
            cmd += "\"#{options[option].to_s.gsub('"', "\\\"")}\" " unless options[option] == ""
          end
        end
        # Appending Task Run [TR] option at the end since appending causing sometimes to append other options in option["TR"] value
        if options["TR"]
          cmd += "/TR \"#{options["TR"]} \" " unless task_action == "DELETE"
        end
        Chef::Log.debug("running: ")
        Chef::Log.debug("    #{cmd}")
        shell_out!(cmd, returns: [0])
      end
      # rubocop:enable Style/StringLiteralsInInterpolation

      def frequency_modifier_allowed
        case new_resource.frequency
        when :minute, :hourly, :daily, :weekly
          true
        when :monthly
          new_resource.months.nil? || %w{ FIRST SECOND THIRD FOURTH LAST LASTDAY }.include?(new_resource.frequency_modifier)
        else
          false
        end
      end

      def get_day(date)
        Date.strptime(date, "%m/%d/%Y").strftime("%a").upcase
      end
    end
  end
end
