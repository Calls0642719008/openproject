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

class RecurringMeeting < ApplicationRecord
  # Magical maximum of iterations
  MAX_ITERATIONS = 1000
  # Magical maximum of interval, derived from other calendars
  MAX_INTERVAL = 100
  include ::Meeting::VirtualStartTime
  include ::Meeting::MeetingUid
  include Redmine::I18n

  belongs_to :project
  belongs_to :author, class_name: "User"

  validates :start_time, :title, :frequency, :end_after, :time_zone, presence: true
  validates :end_date, presence: { if: -> { end_after_specific_date? } }
  validates :iterations,
            numericality: { only_integer: true,
                            greater_than_or_equal_to: 1,
                            less_than_or_equal_to: MAX_ITERATIONS,
                            if: -> { end_after_iterations? } }
  validates :interval,
            numericality: { only_integer: true,
                            greater_than_or_equal_to: 1,
                            less_than_or_equal_to: MAX_INTERVAL,
                            if: -> { !frequency_working_days? } }

  validate :end_date_constraints,
           if: -> { end_after_specific_date? }

  after_initialize :set_defaults

  # Unset any previously set schedule before running validations
  before_validation :unset_schedule

  before_destroy :remove_jobs
  after_save :unset_schedule

  enum :frequency,
       {
         daily: 0,
         working_days: 1,
         weekly: 2
       },
       prefix: true,
       default: "weekly"

  enum :end_after,
       {
         specific_date: 0,
         iterations: 1,
         never: 3
       },
       prefix: true,
       default: "never"

  has_many :meetings,
           inverse_of: :recurring_meeting,
           dependent: :destroy

  has_many :scheduled_meetings,
           inverse_of: :recurring_meeting,
           dependent: :delete_all

  has_one :template, -> { where(template: true) },
          class_name: "Meeting"

  has_many :recurring_meeting_interim_responses,
           inverse_of: :recurring_meeting,
           dependent: :destroy

  scope :visible, ->(*args) {
    includes(:project)
      .references(:projects)
      .merge(Project.allowed_to(args.first || User.current, :view_meetings))
  }

  scope :participated_by, ->(user) {
    left_outer_joins(template: :participants).where(participants: { user_id: user.id })
  }

  # Virtual attributes that can be passed on to the template on save
  virtual_attribute :location do
    nil
  end
  virtual_attribute :duration do
    nil
  end
  virtual_attribute :notify do
    nil
  end

  def will_end?
    last_occurrence.present?
  end

  def has_ended?
    will_end? && last_occurrence < Time.zone.now
  end

  def notify?
    template&.notify?
  end

  def human_frequency
    case frequency
    when "working_days"
      I18n.t("recurring_meeting.frequency.working_days")
    else
      I18n.t("recurring_meeting.frequency.x_#{frequency}", count: interval)
    end
  end

  def human_day_of_week
    I18n.t("recurring_meeting.frequency.every_weekday", day_of_the_week: weekday)
  end

  def weekday
    return I18n.t(:label_empty_element) if start_time.blank?

    I18n.l(start_time, format: "%A")
  end

  def date
    start_time.day.ordinalize
  end

  def start_time
    super&.in_time_zone(time_zone)
  end

  def time_zone_differs?
    time_zone != User.current.time_zone
  end

  def time_zone
    time_zone_string = super
    zone = ActiveSupport::TimeZone[time_zone_string] if time_zone_string.present?

    zone || User.current.time_zone
  end

  def schedule
    @schedule ||= IceCube::Schedule.new(start_time, duration: template&.duration).tap do |s|
      s.add_recurrence_rule count_rule(frequency_rule)
      exclude_non_working_days(s) if frequency_working_days?
    end
  end

  def base_schedule
    case frequency
    when "daily"
      if interval == 1
        human_frequency
      else
        I18n.t("recurring_meeting.in_words.daily_interval", interval:)
      end
    when "working_days"
      I18n.t("recurring_meeting.in_words.working_days")
    when "weekly"
      if interval == 1
        I18n.t("recurring_meeting.in_words.weekly", weekday:)
      else
        I18n.t("recurring_meeting.in_words.weekly_interval", interval:, weekday:)
      end
    end
  end

  def full_schedule_in_words # rubocop:disable Metrics/AbcSize
    time = "#{format_time(start_time, time_zone:, include_date: false)} (#{friendly_timezone_name(time_zone)})"
    if has_ended?
      I18n.t("recurring_meeting.in_words.full_past",
             base: base_schedule,
             time:,
             end_date: format_date(last_occurrence))
    elsif will_end?
      I18n.t("recurring_meeting.in_words.full",
             base: base_schedule,
             time:,
             end_date: format_date(last_occurrence))
    else
      I18n.t("recurring_meeting.in_words.never_ending",
             base: base_schedule,
             time:)
    end
  end

  def human_frequency_schedule
    formatted_time = format_time(start_time, time_zone:, include_date: false)
    time = time_zone_differs? ? "#{formatted_time} (#{friendly_timezone_name(time_zone)})" : formatted_time
    I18n.t("recurring_meeting.in_words.frequency",
           base: base_schedule,
           time:)
  end

  def reschedule_required?(previous: false)
    (previous ? previous_changes : changes)
      .keys
      .intersect?(%w[frequency start_date start_time start_time_hour iterations interval end_after end_date location])
  end

  def scheduled_occurrences(limit:)
    schedule.next_occurrences(limit, Time.current)
  end

  def first_occurrence
    @first_occurrence ||= schedule.first
  end

  def last_occurrence
    return if end_after_never?

    @last_occurrence ||= schedule.last
  end

  def next_occurrence(from_time: Time.current)
    schedule.next_occurrence(from_time)&.to_time
  end

  def previous_occurrence(from_time: Time.current)
    schedule.previous_occurrence(from_time)&.to_time
  end

  delegate :occurs_at?, to: :schedule

  def remaining_occurrences
    case end_after
    when "specific_date"
      schedule.occurrences_between(Time.current, end_date.to_time(:utc).end_of_day)
    when "iterations"
      schedule.remaining_occurrences(Time.current)
    end
  end

  def scheduled_instances(upcoming: true)
    filter_scope = upcoming ? :upcoming : :past
    direction = upcoming ? :asc : :desc

    scheduled_meetings
      .includes(:meeting)
      .public_send(filter_scope)
      .then { |o| filter_scope == :past ? o.not_cancelled : o }
      .order(start_time: direction)
  end

  def upcoming_instantiated_meetings
    @upcoming_instantiated_meetings ||= scheduled_meetings
      .includes(:meeting)
      .not_cancelled
      .joins(:meeting)
      .where("meetings.start_time + (interval '1 hour' * meetings.duration) >= ?", Time.current)
      .order(start_time: :asc)
  end

  def ongoing_meetings
    upcoming_instantiated_meetings
      .includes(:meeting)
      .where(meetings: { start_time: ..Time.current })
      .order(start_time: :asc)
  end

  def upcoming_cancelled_meetings
    scheduled_meetings
      .upcoming
      .cancelled
      .order(start_time: :asc)
  end

  def instantiated_meetings
    meetings.not_templated
  end

  private

  def unset_schedule
    @schedule = nil
    @first_occurence = nil
    @last_occurrence = nil
  end

  def end_date_constraints
    return if end_date.nil?

    if parsed_start_date.present? && end_date < parsed_start_date
      errors.add(:end_date, :after, date: format_date(parsed_start_date))
    end
  end

  def exclude_non_working_days(schedule)
    NonWorkingDay
      .where(date: start_date...)
      .pluck(:date)
      .each do |date|
      schedule.add_exception_time(date.to_time(:utc))
    end
  end

  def frequency_rule
    case frequency
    when "daily"
      IceCube::Rule.daily(interval)
    when "working_days"
      IceCube::Rule
        .weekly(interval)
        .day(*Setting.working_day_names)
    when "weekly"
      IceCube::Rule.weekly(interval)
    else
      raise NotImplementedError
    end
  end

  def count_rule(rule)
    case end_after
    when "specific_date"
      rule.until((end_date + 1.day).to_time(:utc))
    when "iterations"
      rule.count(iterations)
    else
      rule
    end
  end

  def set_defaults
    self.end_date ||= 1.year.from_now if end_after_specific_date?
  end

  def remove_jobs
    RecurringMeetings::InitNextOccurrenceJob.delete_jobs(self)
  end
end
