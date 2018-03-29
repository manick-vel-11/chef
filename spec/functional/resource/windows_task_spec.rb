#
# Author:: Nimisha Sharad (<nimisha.sharad@msystechnologies.com>)
# Copyright:: Copyright (c) 2016 Chef Software, Inc.
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

require "spec_helper"
require "chef/provider/windows_task"

describe Chef::Resource::WindowsTask, :windows_only do
  let(:task_name) { "chef-client" }
  let(:new_resource) { Chef::Resource::WindowsTask.new(task_name) }
  let(:windows_task_provider) do
    node = Chef::Node.new
    events = Chef::EventDispatch::Dispatcher.new
    run_context = Chef::RunContext.new(node, {}, events)
    Chef::Provider::WindowsTask.new(new_resource, run_context)
  end

  describe "action :create" do
    after { delete_task }
    context "when frequency and frequency_modifier are not passed" do
      subject do
        new_resource = Chef::Resource::WindowsTask.new(task_name, run_context)
        new_resource.command task_name
        new_resource.execution_time_limit = 259200 / 60 # converting "PT72H" into minutes and passing here since win32-taskscheduler accespts this
        # Make sure MM/DD/YYYY is accepted
        new_resource.start_day "09/20/2017"
        new_resource
      end

      it "creates a scheduled task to run every 1 hr starting on 09/20/2017" do
        call_for_create_action
        #loading current resource again to check new task is creted and it matches task parameters
        current_resource = call_for_load_current_resource
        expect(current_resource.exists).to eq(true)
        expect(current_resource.task.application_name).to eq("chef-client")
        trigger_details = current_resource.task.trigger(0)
        expect(trigger_details[:start_year]).to eq("2017")
        expect(trigger_details[:start_month]).to eq("09")
        expect(trigger_details[:start_day]).to eq("20")
        expect(trigger_details[:minutes_interval]).to eq(60)
        expect(trigger_details[:trigger_type]).to eq(1)
      end

      it "does not converge the resource if it is already converged" do
        subject.run_action(:create)
        subject.run_action(:create)
        expect(subject).not_to be_updated_by_last_action
      end
    end

    context "frequency :minute" do
      subject do
        new_resource = Chef::Resource::WindowsTask.new(task_name, run_context)
        new_resource.command task_name
        new_resource.run_level :highest
        new_resource.frequency :minute
        new_resource.frequency_modifier 15
        new_resource.execution_time_limit = 259200 / 60 # converting "PT72H" into minutes and passing here since win32-taskscheduler accespts this
        new_resource
      end

      it "creates a scheduled task that runs after every 15 minutes" do
        call_for_create_action
        #loading current resource again to check new task is creted and it matches task parameters
        current_resource = call_for_load_current_resource
        expect(current_resource.exists).to eq(true)
        trigger_details = current_resource.task.trigger(0)
        expect(current_resource.task.application_name).to eq("chef-client")
        expect(trigger_details[:minutes_interval]).to eq(15)
        expect(trigger_details[:trigger_type]).to eq(1)
        expect(current_resource.task.principals[:run_level]).to eq(1)
      end

      it "does not converge the resource if it is already converged" do
        subject.run_action(:create)
        subject.run_action(:create)
        expect(subject).not_to be_updated_by_last_action
      end
    end

    context "frequency :hourly" do
      subject do
        new_resource = Chef::Resource::WindowsTask.new(task_name, run_context)
        new_resource.command task_name
        new_resource.run_level :highest
        new_resource.frequency :hourly
        new_resource.frequency_modifier 3
        new_resource.execution_time_limit = 259200 / 60 # converting "PT72H" into minutes and passing here since win32-taskscheduler accespts this
        new_resource
      end

      it "creates a scheduled task that runs after every 3 hrs" do
        call_for_create_action
        #loading current resource again to check new task is creted and it matches task parameters
        current_resource = call_for_load_current_resource
        expect(current_resource.exists).to eq(true)
        trigger_details = current_resource.task.trigger(0)
        expect(current_resource.task.application_name).to eq("chef-client")
        expect(trigger_details[:minutes_interval]).to eq(180)
        expect(trigger_details[:trigger_type]).to eq(1)
      end

      it "does not converge the resource if it is already converged" do
        subject.run_action(:create)
        subject.run_action(:create)
        expect(subject).not_to be_updated_by_last_action
      end
    end

    context "frequency :daily" do
      subject do
        new_resource = Chef::Resource::WindowsTask.new(task_name, run_context)
        new_resource.command task_name
        new_resource.run_level :highest
        new_resource.frequency :daily
        new_resource.execution_time_limit = 259200 / 60 # converting "PT72H" into minutes and passing here since win32-taskscheduler accespts this
        new_resource
      end

      it "creates a scheduled task to run daily" do
        call_for_create_action
        #loading current resource again to check new task is creted and it matches task parameters
        current_resource = call_for_load_current_resource
        expect(current_resource.exists).to eq(true)
        trigger_details = current_resource.task.trigger(0)
        expect(current_resource.task.application_name).to eq("chef-client")
        expect(trigger_details[:trigger_type]).to eq(2)
        expect(current_resource.task.principals[:run_level]).to eq(1)
        expect(trigger_details[:type][:days_interval]).to eq(1)
      end

      it "does not converge the resource if it is already converged" do
        subject.run_action(:create)
        subject.run_action(:create)
        expect(subject).not_to be_updated_by_last_action
      end
    end

    describe "frequency :monthly" do
      context "Pass start_day and start_time compulsory" do
        subject do
          new_resource = Chef::Resource::WindowsTask.new(task_name, run_context)
          new_resource.command task_name
          new_resource.run_level :highest
          new_resource.frequency :monthly
          new_resource.execution_time_limit = 259200 / 60 # converting "PT72H" into minutes and passing here since win32-taskscheduler accespts this
          new_resource.start_day "02/12/2018"
          new_resource.start_time "05:15"
          new_resource
        end

        it "creates a scheduled task to run monthly on first day of the month" do
          call_for_create_action
          #loading current resource again to check new task is creted and it matches task parameters
          current_resource = call_for_load_current_resource
          expect(current_resource.exists).to eq(true)
          trigger_details = current_resource.task.trigger(0)
          expect(current_resource.task.application_name).to eq("chef-client")
          expect(trigger_details[:trigger_type]).to eq(4)
          expect(current_resource.task.principals[:run_level]).to eq(1)
          expect(trigger_details[:type][:days]).to eq(1)
          expect(trigger_details[:type][:months]).to eq(4095)
        end

        it "does not converge the resource if it is already converged" do
          subject.run_action(:create)
          subject.run_action(:create)
          expect(subject).not_to be_updated_by_last_action
        end

        it "creates a scheduled task to run monthly on first, second and third day of the month" do
          subject.day "1, 2, 3"
          call_for_create_action
          #loading current resource again to check new task is created and it matches task parameters
          current_resource = call_for_load_current_resource
          expect(current_resource.exists).to eq(true)
          trigger_details = current_resource.task.trigger(0)
          expect(current_resource.task.application_name).to eq("chef-client")
          expect(trigger_details[:trigger_type]).to eq(4)
          expect(current_resource.task.principals[:run_level]).to eq(1)
          expect(trigger_details[:type][:days]).to eq(7)
          expect(trigger_details[:type][:months]).to eq(4095)
        end

        it "does not converge the resource if it is already converged" do
          subject.day "1, 2, 3"
          subject.run_action(:create)
          subject.run_action(:create)
          expect(subject).not_to be_updated_by_last_action
        end

        it "creates a scheduled task to run monthly on 1, 2, 3, 4, 8, 20, 21, 15, 28, 31 day of the month" do
          subject.day "1, 2, 3, 4, 8, 20, 21, 15, 28, 31"
          call_for_create_action
          #loading current resource again to check new task is created and it matches task parameters
          current_resource = call_for_load_current_resource
          expect(current_resource.exists).to eq(true)
          trigger_details = current_resource.task.trigger(0)
          expect(current_resource.task.application_name).to eq("chef-client")
          expect(trigger_details[:trigger_type]).to eq(4)
          expect(current_resource.task.principals[:run_level]).to eq(1)
          expect(trigger_details[:type][:days]).to eq(1209548943) #TODO:: windows_task_provider.send(:days_of_month)
          expect(trigger_details[:type][:months]).to eq(4095) #windows_task_provider.send(:months_of_year)
        end

        it "does not converge the resource if it is already converged" do
          subject.day "1, 2, 3, 4, 8, 20, 21, 15, 28, 31"
          subject.run_action(:create)
          subject.run_action(:create)
          expect(subject).not_to be_updated_by_last_action
        end

        it "creates a scheduled task to run monthly on Jan, Feb, Apr, Dec on 1st 2nd 3rd 4th 8th and 20th day of these months" do
          subject.day "1, 2, 3, 4, 8, 20, 21, 30"
          subject.months "Jan, Feb, May, Sep, Dec"
          call_for_create_action
          #loading current resource again to check new task is created and it matches task parameters
          current_resource = call_for_load_current_resource
          expect(current_resource.exists).to eq(true)
          trigger_details = current_resource.task.trigger(0)
          expect(current_resource.task.application_name).to eq("chef-client")
          expect(trigger_details[:trigger_type]).to eq(4)
          expect(current_resource.task.principals[:run_level]).to eq(1)
          expect(trigger_details[:type][:days]).to eq(538443919) #TODO:windows_task_provider.send(:days_of_month)
          expect(trigger_details[:type][:months]).to eq(2323) #windows_task_provider.send(:months_of_year)
        end

        it "does not converge the resource if it is already converged" do
          subject.day "1, 2, 3, 4, 8, 20, 21, 30"
          subject.months "Jan, Feb, May, Sep, Dec"
          subject.run_action(:create)
          subject.run_action(:create)
          expect(subject).not_to be_updated_by_last_action
        end

        it "creates a scheduled task to run monthly by giving day option with frequency_modifier" do
          subject.frequency_modifier "First"
          subject.day "Mon, Fri, Sun"
          call_for_create_action
          #loading current resource again to check new task is created and it matches task parameters
          current_resource = call_for_load_current_resource
          expect(current_resource.exists).to eq(true)
          trigger_details = current_resource.task.trigger(0)
          expect(current_resource.task.application_name).to eq("chef-client")
          expect(trigger_details[:trigger_type]).to eq(5)
          expect(current_resource.task.principals[:run_level]).to eq(1)
          expect(trigger_details[:type][:days_of_week]).to eq(35)
          expect(trigger_details[:type][:weeks_of_month]).to eq(1)
          expect(trigger_details[:type][:months]).to eq(4095) #windows_task_provider.send(:months_of_year)
        end

        it "does not converge the resource if it is already converged" do
          subject.frequency_modifier "First"
          subject.day "Mon, Fri, Sun"
          subject.run_action(:create)
          subject.run_action(:create)
          expect(subject).not_to be_updated_by_last_action
        end
      end

      context "Pass either start day or start time by passing day compulsory or only pass frequency_modifier" do
        subject do
          new_resource = Chef::Resource::WindowsTask.new(task_name, run_context)
          new_resource.command task_name
          new_resource.run_level :highest
          new_resource.frequency :monthly
          new_resource.execution_time_limit = 259200 / 60 # converting "PT72H" into minutes and passing here since win32-taskscheduler accespts this
          new_resource
        end

        it "creates a scheduled task to run monthly on second day of the month" do
          subject.day "2"
          subject.start_day "03/07/2018"
          call_for_create_action
          #loading current resource again to check new task is creted and it matches task parameters
          current_resource = call_for_load_current_resource
          expect(current_resource.exists).to eq(true)
          trigger_details = current_resource.task.trigger(0)
          expect(current_resource.task.application_name).to eq("chef-client")
          expect(trigger_details[:trigger_type]).to eq(4)
          expect(current_resource.task.principals[:run_level]).to eq(1)
          expect(trigger_details[:type][:days]).to eq(2)
          expect(trigger_details[:type][:months]).to eq(4095)
        end

        it "does not converge the resource if it is already converged" do
          subject.day "2"
          subject.start_day "03/07/2018"
          subject.run_action(:create)
          subject.run_action(:create)
          expect(subject).not_to be_updated_by_last_action
        end

        it "creates a scheduled task to run monthly on first, second and third day of the month" do
          subject.day "1,2,3"
          call_for_create_action
          #loading current resource again to check new task is creted and it matches task parameters
          current_resource = call_for_load_current_resource
          expect(current_resource.exists).to eq(true)
          trigger_details = current_resource.task.trigger(0)
          expect(current_resource.task.application_name).to eq("chef-client")
          expect(trigger_details[:trigger_type]).to eq(4)
          expect(current_resource.task.principals[:run_level]).to eq(1)
          expect(trigger_details[:type][:days]).to eq(7)
          expect(trigger_details[:type][:months]).to eq(4095)
        end

        it "does not converge the resource if it is already converged" do
          subject.day "1,2,3"
          subject.run_action(:create)
          subject.run_action(:create)
          expect(subject).not_to be_updated_by_last_action
        end

## TODO: if frequency modifier=2 is given it creates the monthly frequency with interval of 2 months not handled in code
        # it "creates a scheduled task to run monthly on each wednesday of the month" do
        #   subject.frequency_modifier "2"
        #   call_for_create_action
        #   #loading current resource again to check new task is creted and it matches task parameters
        #   current_resource = call_for_load_current_resource
        #   expect(current_resource.exists).to eq(true)
        #   trigger_details = current_resource.task.trigger(0)
        #   expect(current_resource.task.application_name).to eq("chef-client")
        #   expect(trigger_details[:trigger_type]).to eq(5)
        #   expect(current_resource.task.principals[:run_level]).to eq(1)
        #   expect(trigger_details[:type][:days_of_week]).to eq(8)
        #   expect(trigger_details[:type][:weeks_of_month]).to eq(1)
        #   expect(trigger_details[:type][:months]).to eq(4095) #windows_task_provider.send(:months_of_year)
        # end

        # it "does not converge the resource if it is already converged" do
        #   subject.frequency_modifier "2"
        #   subject.run_action(:create)
        #   subject.run_action(:create)
        #   expect(subject).not_to be_updated_by_last_action
        # end
      end
    end

    context "frequency :once" do
      subject do
        new_resource = Chef::Resource::WindowsTask.new(task_name, run_context)
        new_resource.command task_name
        new_resource.run_level :highest
        new_resource.frequency :once
        new_resource.execution_time_limit = 259200 / 60 # converting "PT72H" into minutes and passing here since win32-taskscheduler accespts this
        new_resource
      end

      context "when start_time is not provided" do
        it "raises argument error" do
          expect { subject.after_created }.to raise_error("`start_time` needs to be provided with `frequency :once`")
        end
      end

      context "when start_time is provided" do
        it "creates the scheduled task to run once at 5pm" do
          subject.start_time "17:00"
          call_for_create_action
          #loading current resource again to check new task is creted and it matches task parameters
          current_resource = call_for_load_current_resource
          expect(current_resource.exists).to eq(true)
          trigger_details = current_resource.task.trigger(0)
          expect(current_resource.task.application_name).to eq("chef-client")
          expect(trigger_details[:trigger_type]).to eq(1)
          expect(current_resource.task.principals[:run_level]).to eq(1)
          expect("#{trigger_details[:start_hour]}:#{trigger_details[:start_minute]}" ).to eq(subject.start_time)
        end

        it "does not converge the resource if it is already converged" do
          subject.start_time "17:00"
          subject.run_action(:create)
          subject.run_action(:create)
          expect(subject).not_to be_updated_by_last_action
        end
      end
    end

    context "frequency :onstart" do
      subject do
        new_resource = Chef::Resource::WindowsTask.new(task_name, run_context)
        new_resource.command task_name
        new_resource.run_level :highest
        new_resource.frequency :onstart
        new_resource.execution_time_limit = 259200 / 60 # converting "PT72H" into minutes and passing here since win32-taskscheduler accespts this
        new_resource
      end

      it "creates the scheduled task to run at system start up" do
        call_for_create_action
        #loading current resource again to check new task is creted and it matches task parameters
        current_resource = call_for_load_current_resource
        expect(current_resource.exists).to eq(true)
        trigger_details = current_resource.task.trigger(0)
        expect(current_resource.task.application_name).to eq("chef-client")
        expect(current_resource.task.principals[:run_level]).to eq(1)
        expect(trigger_details[:trigger_type]).to eq(8)
      end

      it "does not converge the resource if it is already converged" do
        subject.run_action(:create)
        subject.run_action(:create)
        expect(subject).not_to be_updated_by_last_action
      end
    end

    context "frequency :weekly" do
      subject do
        new_resource = Chef::Resource::WindowsTask.new(task_name, run_context)
        new_resource.command task_name
        new_resource.run_level :highest
        new_resource.frequency :weekly
        new_resource.execution_time_limit = 259200 / 60 # converting "PT72H" into minutes and passing here since win32-taskscheduler accespts this
        new_resource
      end

      it "creates the scheduled task to run weekly" do
        call_for_create_action
        #loading current resource again to check new task is creted and it matches task parameters
        current_resource = call_for_load_current_resource
        expect(current_resource.exists).to eq(true)
        trigger_details = current_resource.task.trigger(0)
        expect(current_resource.task.application_name).to eq("chef-client")
        expect(current_resource.task.principals[:run_level]).to eq(1)
        expect(trigger_details[:trigger_type]).to eq(3)
        expect(trigger_details[:type][:weeks_interval]).to eq(1)
      end

      it "does not converge the resource if it is already converged" do
        subject.run_action(:create)
        subject.run_action(:create)
        expect(subject).not_to be_updated_by_last_action
      end

      context "when days are provided" do
        it "creates the scheduled task to run on particular days" do
          subject.day "Mon, Fri"
          subject.frequency_modifier 2
          call_for_create_action
          #loading current resource again to check new task is creted and it matches task parameters
          current_resource = call_for_load_current_resource
          expect(current_resource.exists).to eq(true)
          trigger_details = current_resource.task.trigger(0)
          expect(current_resource.task.application_name).to eq("chef-client")
          expect(current_resource.task.principals[:run_level]).to eq(1)
          expect(trigger_details[:trigger_type]).to eq(3)
          expect(trigger_details[:type][:weeks_interval]).to eq(2)
          expect(trigger_details[:type][:days_of_week]).to eq(34)
        end

        it "does not converge the resource if it is already converged" do
          subject.day "Mon, Fri"
          subject.frequency_modifier 2
          subject.run_action(:create)
          subject.run_action(:create)
          expect(subject).not_to be_updated_by_last_action
        end
      end

      context "when invalid day is passed" do
        it "raises error" do
          subject.day "abc"
          expect { subject.after_created }.to raise_error("day property invalid. Only valid values are: MON, TUE, WED, THU, FRI, SAT, SUN, *. Multiple values must be separated by a comma.")
        end
      end

      context "when months are passed" do
        it "raises error that months are supported only when frequency=:monthly" do
          subject.months "Jan"
          expect { subject.after_created }.to raise_error("months property is only valid for tasks that run monthly")
        end
      end

      context "frequency :on_logon" do
        subject do
          new_resource = Chef::Resource::WindowsTask.new(task_name, run_context)
          new_resource.command task_name
          new_resource.run_level :highest
          new_resource.frequency :on_logon
          new_resource.execution_time_limit = 259200 / 60 # converting "PT72H" into minutes and passing here since win32-taskscheduler accespts this
          new_resource
        end

        it "creates the scheduled task to on logon" do
          call_for_create_action
          #loading current resource again to check new task is creted and it matches task parameters
          current_resource = call_for_load_current_resource
          expect(current_resource.exists).to eq(true)
          trigger_details = current_resource.task.trigger(0)
          expect(current_resource.task.application_name).to eq("chef-client")
          expect(current_resource.task.principals[:run_level]).to eq(1)
          expect(trigger_details[:trigger_type]).to eq(9)
        end

        it "does not converge the resource if it is already converged" do
          subject.run_action(:create)
          subject.run_action(:create)
          expect(subject).not_to be_updated_by_last_action
        end
      end
    end

    context "frequency :on_idle" do
      subject do
        new_resource = Chef::Resource::WindowsTask.new(task_name, run_context)
        new_resource.command task_name
        new_resource.run_level :highest
        new_resource.frequency :on_idle
        new_resource.execution_time_limit = 259200 / 60 # converting "PT72H" into minutes and passing here since win32-taskscheduler accespts this
        new_resource
      end

      context "when idle_time is not passed" do
        it "raises error" do
          expect { subject.after_created }.to raise_error("idle_time value should be set for :on_idle frequency.")
        end
      end

      context "when idle_time is passed" do
        it "creates the scheduled task to run when system is idle" do
          subject.idle_time 20
          call_for_create_action
          #loading current resource again to check new task is creted and it matches task parameters
          current_resource = call_for_load_current_resource
          expect(current_resource.exists).to eq(true)
          trigger_details = current_resource.task.trigger(0)
          expect(current_resource.task.application_name).to eq("chef-client")
          expect(current_resource.task.principals[:run_level]).to eq(1)
          expect(trigger_details[:trigger_type]).to eq(6)
          expect(current_resource.task.settings[:idle_settings][:idle_duration]).to eq("PT20M")
          expect(current_resource.task.settings[:run_only_if_idle]).to eq(true)
        end

        it "does not converge the resource if it is already converged" do
          subject.idle_time 20
          subject.run_action(:create)
          subject.run_action(:create)
          expect(subject).not_to be_updated_by_last_action
        end
      end
    end

    context "when random_delay is passed" do
      subject do
        new_resource = Chef::Resource::WindowsTask.new(task_name, run_context)
        new_resource.command task_name
        new_resource.run_level :highest
        new_resource.execution_time_limit = 259200 / 60 # converting "PT72H" into minutes and passing here since win32-taskscheduler accespts this
        new_resource
      end

      it "sets the random_delay for frequency :minute" do
        subject.frequency :minute
        subject.random_delay "20"
        call_for_create_action
        #loading current resource again to check new task is creted and it matches task parameters
        current_resource = call_for_load_current_resource
        expect(current_resource.exists).to eq(true)
        trigger_details = current_resource.task.trigger(0)
        expect(current_resource.task.application_name).to eq("chef-client")
        expect(current_resource.task.principals[:run_level]).to eq(1)
        expect(trigger_details[:trigger_type]).to eq(1)
        expect(trigger_details[:random_minutes_interval]).to eq(20)
      end

      it "does not converge the resource if it is already converged" do
        subject.frequency :minute
        subject.random_delay "20"
        subject.run_action(:create)
        subject.run_action(:create)
        expect(subject).not_to be_updated_by_last_action
      end

      it "raises error if invalid random_delay is passed" do
        subject.frequency :minute
        subject.random_delay "abc"
        expect { subject.after_created }.to raise_error("Invalid value passed for `random_delay`. Please pass seconds as an Integer (e.g. 60) or a String with numeric values only (e.g. '60').")
      end

      it "raises error if random_delay is passed with frequency on_idle" do
        subject.frequency :on_idle
        subject.random_delay "20"
        expect { subject.after_created }.to raise_error("`random_delay` property is supported only for frequency :once, :minute, :hourly, :daily, :weekly and :monthly")
      end
    end

    context "frequency :none" do
      subject do
        new_resource = Chef::Resource::WindowsTask.new(task_name, run_context)
        new_resource.command task_name
        new_resource.run_level :highest
        new_resource.frequency :none
        new_resource.execution_time_limit = 259200 / 60 # converting "PT72H" into minutes and passing here since win32-taskscheduler accespts this
        new_resource
      end

      it "creates the scheduled task to run on demand only" do
        call_for_create_action
        #loading current resource again to check new task is creted and it matches task parameters
        current_resource = call_for_load_current_resource
        expect(current_resource.exists).to eq(true)

        expect(current_resource.task.application_name).to eq("chef-client")
        expect(current_resource.task.principals[:run_level]).to eq(1)
        expect(current_resource.task.trigger_count).to eq(0)
      end

      it "does not converge the resource if it is already converged" do
        subject.run_action(:create)
        subject.run_action(:create)
        expect(subject).not_to be_updated_by_last_action
      end
    end
  end

  describe "Examples of idempotent checks for each frequency" do
    after { delete_task }
    context "For frequency :once" do
      subject do
        new_resource = Chef::Resource::WindowsTask.new(task_name, run_context)
        new_resource.command task_name
        new_resource.run_level :highest
        new_resource.frequency :once
        new_resource.start_time "17:00"
        new_resource.execution_time_limit = 259200 / 60 # converting "PT72H" into minutes and passing here since win32-taskscheduler accespts this
        new_resource
      end

      it "create task by adding frequency_modifier as 1" do
        subject.frequency_modifier 1
        subject.run_action(:create)
        subject.run_action(:create)
        expect(subject).not_to be_updated_by_last_action
      end

      it "create task by adding frequency_modifier as 5" do
        subject.frequency_modifier 5
        subject.run_action(:create)
        subject.run_action(:create)
        expect(subject).not_to be_updated_by_last_action
      end
    end

    context "For frequency :none" do
      subject do
        new_resource = Chef::Resource::WindowsTask.new(task_name, run_context)
        new_resource.command task_name
        new_resource.run_level :highest
        new_resource.execution_time_limit = 259200 / 60 # converting "PT72H" into minutes and passing here since win32-taskscheduler accespts this
        new_resource.frequency :none
        new_resource
      end

      it "create task by adding frequency_modifier as 1" do
        subject.frequency_modifier 1
        subject.run_action(:create)
        subject.run_action(:create)
        expect(subject).not_to be_updated_by_last_action
      end

      it "create task by adding frequency_modifier as 5" do
        subject.frequency_modifier 5
        subject.run_action(:create)
        subject.run_action(:create)
        expect(subject).not_to be_updated_by_last_action
      end
    end

    context "For frequency :weekly" do
      subject do
        new_resource = Chef::Resource::WindowsTask.new(task_name, run_context)
        new_resource.command task_name
        new_resource.run_level :highest
        new_resource.frequency :weekly
        new_resource.execution_time_limit = 259200 / 60 # converting "PT72H" into minutes and passing here since win32-taskscheduler accespts this
        new_resource
      end

      it "create task by adding start_day" do
        subject.start_day "12/28/2018"
        subject.run_action(:create)
        subject.run_action(:create)
        expect(subject).not_to be_updated_by_last_action
      end

      it "create task by adding frequency_modifier and random_delay" do
        subject.frequency_modifier 3
        subject.random_delay "60"
        subject.run_action(:create)
        subject.run_action(:create)
        expect(subject).not_to be_updated_by_last_action
      end
    end

    context "For frequency :monthly" do
      subject do
        new_resource = Chef::Resource::WindowsTask.new(task_name, run_context)
        new_resource.command task_name
        new_resource.run_level :highest
        new_resource.frequency :once
        new_resource.start_time "17:00"
        new_resource.execution_time_limit = 259200 / 60 # converting "PT72H" into minutes and passing here since win32-taskscheduler accespts this
        new_resource
      end

      it "create task by adding frequency_modifier as 1" do
        subject.frequency_modifier 1
        subject.run_action(:create)
        subject.run_action(:create)
        expect(subject).not_to be_updated_by_last_action
      end

      it "create task by adding frequency_modifier as 5" do
        subject.frequency_modifier 5
        subject.run_action(:create)
        subject.run_action(:create)
        expect(subject).not_to be_updated_by_last_action
      end
    end

    context "For frequency :hourly" do
      subject do
        new_resource = Chef::Resource::WindowsTask.new(task_name, run_context)
        new_resource.command task_name
        new_resource.run_level :highest
        new_resource.frequency :hourly
        new_resource.frequency_modifier 5
        new_resource.random_delay "2400"
        new_resource.execution_time_limit = 259200 / 60 # converting "PT72H" into minutes and passing here since win32-taskscheduler accespts this
        new_resource
      end

      it "create task by adding frequency_modifier and random_delay" do
        subject.run_action(:create)
        subject.run_action(:create)
        expect(subject).not_to be_updated_by_last_action
      end
    end

    context "For frequency :daily" do
      subject do
        new_resource = Chef::Resource::WindowsTask.new(task_name, run_context)
        new_resource.command task_name
        new_resource.run_level :highest
        new_resource.frequency :daily
        new_resource.frequency_modifier 2
        new_resource.random_delay "2400"
        new_resource.execution_time_limit = 259200 / 60 # converting "PT72H" into minutes and passing here since win32-taskscheduler accespts this
        new_resource
      end

      it "create task by adding frequency_modifier and random_delay" do
        subject.run_action(:create)
        subject.run_action(:create)
        expect(subject).not_to be_updated_by_last_action
      end
    end

    context "For frequency :on_logon" do
      subject do
        new_resource = Chef::Resource::WindowsTask.new(task_name, run_context)
        new_resource.command task_name
        new_resource.frequency :on_logon
        new_resource.execution_time_limit = 259200 / 60 # converting "PT72H" into minutes and passing here since win32-taskscheduler accespts this
        new_resource
      end

      it "create task by adding frequency_modifier and random_delay" do
        subject.run_action(:create)
        subject.run_action(:create)
        expect(subject).not_to be_updated_by_last_action
      end

      it "create task by adding frequency_modifier as 5" do
        subject.frequency_modifier 5
        subject.run_action(:create)
        subject.run_action(:create)
        expect(subject).not_to be_updated_by_last_action
      end
    end

    context "For frequency :onstart" do
      subject do
        new_resource = Chef::Resource::WindowsTask.new(task_name, run_context)
        new_resource.command task_name
        new_resource.run_level :highest
        new_resource.frequency :onstart
        new_resource.frequency_modifier 20
        new_resource.execution_time_limit = 259200 / 60 # converting "PT72H" into minutes and passing here since win32-taskscheduler accespts this
        new_resource
      end

      it "create task by adding frequency_modifier as 20" do
        subject.run_action(:create)
        subject.run_action(:create)
        expect(subject).not_to be_updated_by_last_action
      end
    end
  end

  describe "#after_created" do
    subject do
      new_resource = Chef::Resource::WindowsTask.new(task_name, run_context)
      new_resource.command task_name
      new_resource.run_level :highest
      new_resource.execution_time_limit = 259200 / 60 # converting "PT72H" into minutes and passing here since win32-taskscheduler accespts this
      new_resource
    end

    context "when start_day is passed with frequency :onstart" do
      it "raises error" do
        subject.frequency :onstart
        subject.start_day "09/20/2017"
        expect { subject.after_created }.to raise_error("`start_day` property is not supported with frequency: onstart")
      end
    end

    context "when a non-system user is passed without password" do
      it "raises error" do
        subject.user "Administrator"
        subject.frequency :onstart
        expect { subject.after_created }.to raise_error(%q{Cannot specify a user other than the system users without specifying a password!. Valid passwordless users: 'NT AUTHORITY\SYSTEM', 'SYSTEM', 'NT AUTHORITY\LOCALSERVICE', 'NT AUTHORITY\NETWORKSERVICE', 'BUILTIN\USERS', 'USERS'})
      end
    end

    context "when interactive_enabled is passed for a System user without password" do
      it "raises error" do
        subject.interactive_enabled true
        subject.frequency :onstart
        expect { subject.after_created }.to raise_error("Please provide the password when attempting to set interactive/non-interactive.")
      end
    end

    context "when frequency_modifier > 1439 is passed for frequency=:minute" do
      it "raises error" do
        subject.frequency_modifier 1450
        subject.frequency :minute
        expect { subject.after_created }.to raise_error("frequency_modifier value 1450 is invalid. Valid values for :minute frequency are 1 - 1439.")
      end
    end

    context "when frequency_modifier > 23 is passed for frequency=:minute" do
      it "raises error" do
        subject.frequency_modifier 24
        subject.frequency :hourly
        expect { subject.after_created }.to raise_error("frequency_modifier value 24 is invalid. Valid values for :hourly frequency are 1 - 23.")
      end
    end

    context "when frequency_modifier > 23 is passed for frequency=:minute" do
      it "raises error" do
        subject.frequency_modifier 366
        subject.frequency :daily
        expect { subject.after_created }.to raise_error("frequency_modifier value 366 is invalid. Valid values for :daily frequency are 1 - 365.")
      end
    end

    context "when frequency_modifier > 52 is passed for frequency=:minute" do
      it "raises error" do
        subject.frequency_modifier 53
        subject.frequency :weekly
        expect { subject.after_created }.to raise_error("frequency_modifier value 53 is invalid. Valid values for :weekly frequency are 1 - 52.")
      end
    end

    context "when invalid frequency_modifier is passed for :monthly frequency" do
      it "raises error" do
        subject.frequency :monthly
        subject.frequency_modifier "13"
        expect { subject.after_created }.to raise_error("frequency_modifier value 13 is invalid. Valid values for :monthly frequency are 1 - 12, 'FIRST', 'SECOND', 'THIRD', 'FOURTH', 'LAST', 'LASTDAY'.")
      end
    end

    context "when invalid frequency_modifier is passed for :monthly frequency" do
      it "raises error" do
        subject.frequency :monthly
        subject.frequency_modifier "xyz"
        expect { subject.after_created }.to raise_error("frequency_modifier value xyz is invalid. Valid values for :monthly frequency are 1 - 12, 'FIRST', 'SECOND', 'THIRD', 'FOURTH', 'LAST', 'LASTDAY'.")
      end
    end

    context "when invalid months are passed" do
      it "raises error" do
        subject.months "xyz"
        subject.frequency :monthly
        expect { subject.after_created }.to raise_error("months property invalid. Only valid values are: JAN, FEB, MAR, APR, MAY, JUN, JUL, AUG, SEP, OCT, NOV, DEC, *. Multiple values must be separated by a comma.")
      end
    end

    context "when idle_time > 999 is passed" do
      it "raises error" do
        subject.idle_time 1000
        subject.frequency :on_idle
        expect { subject.after_created }.to raise_error("idle_time value 1000 is invalid. Valid values for :on_idle frequency are 1 - 999.")
      end
    end

    context "when idle_time is passed for frequency=:monthly" do
      it "raises error" do
        subject.idle_time 300
        subject.frequency :monthly
        expect { subject.after_created }.to raise_error("idle_time property is only valid for tasks that run on_idle")
      end
    end
  end

  describe "action :delete" do
    subject do
      new_resource = Chef::Resource::WindowsTask.new(task_name, run_context)
      new_resource.command task_name
      new_resource.execution_time_limit = 259200 / 60 # converting "PT72H" into minutes and passing here since win32-taskscheduler accespts this
      new_resource
    end

    it "does not converge the resource if it is already converged" do
      subject.run_action(:create)
      subject.run_action(:delete)
      subject.run_action(:delete)
      expect(subject).not_to be_updated_by_last_action
    end

    it "does not converge the resource if it is already converged" do
      subject.run_action(:create)
      subject.run_action(:delete)
      subject.run_action(:delete)
      expect(subject).not_to be_updated_by_last_action
    end
  end

  describe "action :run" do
    after { delete_task }

    subject do
      new_resource = Chef::Resource::WindowsTask.new(task_name, run_context)
      new_resource.command "dir"
      new_resource.run_level :highest
      new_resource.execution_time_limit = 259200 / 60 # converting "PT72H" into minutes and passing here since
      new_resource
    end

    it "runs the existing task" do
      subject.run_action(:create)
      subject.run_action(:run)
      current_resource = call_for_load_current_resource
      expect(current_resource.task.status).to eq("queued").or eq("runnning") # queued or can be running
    end
  end

  describe "action :end", :volatile do
    after { delete_task }

    subject do
      new_resource = Chef::Resource::WindowsTask.new(task_name, run_context)
      new_resource.command "dir"
      new_resource.run_level :highest
      new_resource.execution_time_limit = 259200 / 60 # converting "PT72H" into minutes and passing here since
      new_resource
    end

    it "ends the running task" do
      subject.run_action(:create)
      subject.run_action(:run)
      subject.run_action(:end)
      current_resource = call_for_load_current_resource
      expect(current_resource.task.status).to eq("queued").or eq("ready") #queued or can be ready
    end
  end

  describe "action :enable" do
    after { delete_task }

    subject do
      new_resource = Chef::Resource::WindowsTask.new(task_name, run_context)
      new_resource.command task_name
      new_resource.execution_time_limit = 259200 / 60 # converting "PT72H" into minutes and passing here since
      new_resource
    end

    it "enables the disabled task" do
      subject.run_action(:create)
      subject.run_action(:disable)
      current_resource = call_for_load_current_resource
      expect(current_resource.task.status).to eq("not scheduled")
      subject.run_action(:enable)
      current_resource = call_for_load_current_resource
      expect(current_resource.task.status).to eq("ready")
    end
  end

  describe "action :disable" do
    after { delete_task }

    subject do
      new_resource = Chef::Resource::WindowsTask.new(task_name, run_context)
      new_resource.command task_name
      new_resource.execution_time_limit = 259200 / 60 # converting "PT72H" into minutes and passing here since
      new_resource
    end

    it "disables the task" do
      subject.run_action(:create)
      subject.run_action(:disable)
      current_resource = call_for_load_current_resource
      expect(current_resource.task.status).to eq("not scheduled")
    end
  end


  def delete_task
    task_to_delete = Chef::Resource::WindowsTask.new(task_name, run_context)
    task_to_delete.run_action(:delete)
  end

  def call_for_create_action
    current_resource = call_for_load_current_resource
    expect(current_resource.exists).to eq(false)
    subject.run_action(:create)
    expect(subject).to be_updated_by_last_action
  end

  def call_for_load_current_resource
    windows_task_provider.send(:load_current_resource)
  end
end
