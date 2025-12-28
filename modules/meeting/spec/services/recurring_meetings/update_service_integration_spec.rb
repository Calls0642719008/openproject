# frozen_string_literal: true

#-- copyright
# OpenProject is an open source project management software.
# Copyright (C) the OpenProject GmbH
#
# This program is free software; you can redistribute it and/or
# modify it under the terms of the GNU General Public License version 3.
#
# OpenProject is a fork of ChiliProject, which is a fork of Redmine. The copyright follows:
# Copyright (C) 2006-2013 Jean-Philippe Lang
# Copyright (C) 2010-2013 the ChiliProject Team
#
# This program is free software; you can redistribute it and/or
# modify it under the terms of the GNU General Public License
# as published by the Free Software Foundation; either version 2
# of the License, or (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program; if not, write to the Free Software
# Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA  02110-1301, USA.
#
# See COPYRIGHT and LICENSE files for more details.
#++

require "spec_helper"

RSpec.describe RecurringMeetings::UpdateService, "integration", type: :model do
  shared_let(:project) { create(:project, enabled_module_names: %i[meetings]) }
  shared_let(:user) do
    create(:user, member_with_permissions: { project => %i(view_meetings edit_meetings) })
  end
  shared_let(:series, refind: true) do
    create(:recurring_meeting,
           project:,
           start_time: Time.zone.tomorrow + 10.hours,
           frequency: "daily",
           interval: 1,
           end_after: "specific_date",
           end_date: 1.month.from_now)
  end

  let(:instance) { described_class.new(model: series, user:) }
  let(:params) { {} }

  let(:service_result) { instance.call(**params) }
  let(:updated_meeting) { service_result.result }

  context "with a cancelled meeting for tomorrow" do
    let!(:scheduled_meeting) do
      create(:scheduled_meeting,
             :cancelled,
             recurring_meeting: series,
             start_time: Time.zone.tomorrow + 1.day + 10.hours)
    end

    context "when updating the start_date to the time of the first cancellation" do
      let(:params) do
        { start_date: Time.zone.tomorrow + 1.day }
      end

      it "removes the cancelled occurrence" do
        expect(service_result).to be_success
        expect(updated_meeting.start_time).to eq(Time.zone.tomorrow + 1.day + 10.hours)

        expect { scheduled_meeting.reload }.to raise_error(ActiveRecord::RecordNotFound)
      end
    end

    context "when updating only the start time hour" do
      let(:params) do
        { start_time_hour: "09:00" }
      end

      it "updates the cancelled occurrence" do
        expect(service_result).to be_success

        scheduled_meeting.reload
        expect(scheduled_meeting.start_time).to eq(Time.zone.tomorrow + 1.day + 9.hours)
      end
    end

    context "when updating the start_date to further in the future" do
      let(:params) do
        { start_date: Time.zone.today + 2.days }
      end

      it "deletes that cancelled occurrence" do
        expect(service_result).to be_success
        expect(updated_meeting.start_time).to eq(Time.zone.today + 2.days + 10.hours)

        expect { scheduled_meeting.reload }.to raise_error(ActiveRecord::RecordNotFound)
      end
    end
  end

  describe "rescheduling job" do
    context "when updating the title" do
      let(:params) do
        { title: "New title" }
      end

      it "does not reschedule" do
        expect { service_result }.not_to have_enqueued_job(RecurringMeetings::InitNextOccurrenceJob)
        expect(service_result).to be_success
      end
    end

    context "when updating the frequency and start_time",
            with_good_job: RecurringMeetings::InitNextOccurrenceJob do
      let(:params) do
        { start_time: Time.zone.today + 2.days + 11.hours }
      end

      before do
        RecurringMeetings::InitNextOccurrenceJob
          .set(wait_until: Time.zone.today + 1.day + 10.hours)
          .perform_later(series)
      end

      it "reschedules and enqueues the next job" do
        job = GoodJob::Job.find_by(job_class: "RecurringMeetings::InitNextOccurrenceJob")
        expect(job.scheduled_at).to eq Time.zone.today + 1.day + 10.hours
        expect(service_result).to be_success
        expect { job.reload }.to raise_error(ActiveRecord::RecordNotFound)

        new_job = GoodJob::Job.find_by(job_class: "RecurringMeetings::InitNextOccurrenceJob")
        expect(new_job.scheduled_at).to eq Time.zone.today + 2.days + 11.hours

        expect(series.upcoming_instantiated_meetings.count).to eq 1
      end
    end

    context "when the template is in draft mode",
            with_good_job: RecurringMeetings::InitNextOccurrenceJob do
      let(:params) do
        { start_time: Time.zone.today + 2.days + 11.hours }
      end

      before do
        series.template.update_column(:state, :draft)
      end

      it "reschedules, but does not init an occurrence (Bug #69175)" do
        expect(service_result).to be_success

        expect(series.upcoming_instantiated_meetings).to be_empty

        series.reload
        expect(series.start_time).to eq Time.zone.today + 2.days + 11.hours
      end
    end
  end

  describe "rescheduling mails" do
    context "when updating the title" do
      let(:params) do
        { title: "New title" }
      end

      it "does not create them" do
        expect(service_result).to be_success
        perform_enqueued_jobs
        expect(ActionMailer::Base.deliveries).to be_empty
      end
    end

    context "when updating the frequency and start_time" do
      let(:params) do
        { start_time: Time.zone.today + 2.days + 11.hours }
      end

      let(:recipient) do
        create(:user, member_with_permissions: { project => %i(view_meetings) })
      end

      before do
        series.template.participants.delete_all
        series.template.participants << MeetingParticipant.new(user: recipient, invited: true)
      end

      it "sends out updated mails" do
        expect(service_result).to be_success
        perform_enqueued_jobs
        expect(ActionMailer::Base.deliveries.count).to eq(1)
        expect(ActionMailer::Base.deliveries.first.subject)
          .to eq "[#{project.name}] Meeting series '#{series.title}' has been updated"
      end
    end

    context "when updating only the location with recipients with different locales" do
      let(:german_author) do
        create(:user,
               language: "de",
               member_with_permissions: { project => %i(view_meetings edit_meetings) })
      end

      let(:english_recipient) do
        create(:user,
               language: "en",
               member_with_permissions: { project => %i(view_meetings) })
      end

      let(:german_recipient) do
        create(:user,
               language: "de",
               member_with_permissions: { project => %i(view_meetings) })
      end

      let(:instance) { described_class.new(model: series, user: german_author) }

      let(:params) { { location: "New location" } }

      before do
        series.update!(author: german_author)
        series.template.participants.delete_all
        series.template.participants << MeetingParticipant.new(user: english_recipient, invited: true)
        series.template.participants << MeetingParticipant.new(user: german_recipient, invited: true)
        series.template.update!(location: "Old location")
      end

      it "does not send a schedule update when not necessary (Bug #67287)" do
        expect(service_result).to be_success
        perform_enqueued_jobs

        expect(ActionMailer::Base.deliveries.count).to eq(2)

        english_mail = ActionMailer::Base.deliveries.find { |m| m.to.include?(english_recipient.mail) }
        german_mail = ActionMailer::Base.deliveries.find { |m| m.to.include?(german_recipient.mail) }

        expect(english_mail.html_part.body).to include("Every day")
        expect(english_mail.html_part.body).not_to include("Jeden Tag")

        expect(german_mail.html_part.body).to include("Jeden Tag")
        expect(german_mail.html_part.body).not_to include("Every day")
      end
    end
  end

  describe "rescheduling occurrences" do
    let!(:scheduled_meetings) do
      Array.new(3) do |i|
        create(:scheduled_meeting,
               :persisted,
               recurring_meeting: series,
               start_time: Time.zone.today + (i + 1).days + 10.hours)
      end
    end

    context "when only changing the time of day" do
      let(:params) do
        { start_time_hour: "14:30" }
      end

      it "updates the time while keeping the same dates" do
        expect(service_result).to be_success

        # Verify each scheduled meeting keeps its date but changes time
        scheduled_meetings.each_with_index do |meeting, index|
          meeting.reload
          expect(meeting.start_time).to eq(Time.zone.today + (index + 1).days + 14.hours + 30.minutes)
        end
      end
    end

    context "when changing the frequency from daily to weekly" do
      let(:params) do
        { frequency: "weekly" }
      end

      it "reschedules all future occurrences to weekly intervals" do
        expect(service_result).to be_success

        # Verify each scheduled meeting is moved to weekly intervals
        scheduled_meetings.each_with_index do |meeting, index|
          meeting.reload
          expect(meeting.start_time).to eq(Time.zone.tomorrow + (index * 7).days + 10.hours)
        end
      end

      context "when one of the scheduled meetings is cancelled" do
        let!(:cancelled_meeting) do
          create(:scheduled_meeting,
                 :cancelled,
                 recurring_meeting: series,
                 start_time: Time.zone.today + 5.days + 10.hours)
        end

        it "removes cancelled schedules" do
          expect(service_result).to be_success
          expect { cancelled_meeting.reload }.to raise_error(ActiveRecord::RecordNotFound)
        end
      end
    end
  end

  describe "updating end conditions" do
    let!(:scheduled_meetings) do
      Array.new(3) do |i|
        create(:scheduled_meeting,
               :persisted,
               recurring_meeting: series,
               start_time: Time.zone.tomorrow + i.days + 10.hours)
      end
    end

    context "when changing end_after to iterations with fewer iterations than scheduled meetings" do
      let(:params) do
        {
          end_after: "iterations",
          iterations: 1
        }
      end

      it "fails validation" do
        expect(service_result).not_to be_success
        expect(service_result.errors.messages[:base]).to include(
          I18n.t("activerecord.errors.models.recurring_meeting.must_cover_existing_meetings", count: 2)
        )
      end
    end

    context "when changing interval to 2, so that previous occurrences overlap" do
      let(:params) do
        {
          interval: 2
        }
      end

      it "succeeds" do
        expect(service_result).to be_success

        # Verify each scheduled meeting is moved to weekly intervals
        scheduled_meetings.each_with_index do |meeting, index|
          meeting.reload
          expect(meeting.start_time).to eq(Time.zone.tomorrow + (index * 2).days + 10.hours)
        end
      end
    end

    context "when changing end_date to before the last scheduled meeting" do
      let(:params) do
        {
          end_after: "specific_date",
          end_date: Time.zone.today + 2.days
        }
      end

      it "fails validation" do
        expect(service_result).not_to be_success
        expect(service_result.errors.messages[:base]).to include(
          I18n.t("activerecord.errors.models.recurring_meeting.must_cover_existing_meetings", count: 1)
        )
      end
    end
  end
end
