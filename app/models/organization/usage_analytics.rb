class Organization
  # Payload for the "Uso dos alunos" tab of the trainer Analytics section. Reads the
  # student-app ahoy event stream (server-side product analytics) scoped to this
  # organization's students over a trailing window, and surfaces behaviour the domain
  # tables can't:
  #
  # - active_students: distinct students active per day (the engagement heartbeat).
  # - session_funnel:  how the in-app workout funnel converts — started → finished,
  #     plus cancelled (which hard-deletes its row, so the event is its only trace).
  # - app_open_states: what students face when they open the app, from home_viewed's
  #     entry_state (resume / can-start / rest-day / no-plan).
  #
  # Sibling of Organization::Analytics (domain-table activity counts); this one is the
  # event-derived behavioural view. Activation events (setup, sign-in) are identity-
  # level — they precede profile selection, so they carry no organization_id and are
  # intentionally out of this per-organization view.
  class UsageAnalytics
    DAYS = 14
    ENTRY_STATES = %w[ resume can_start rest_day no_plan ].freeze

    def initialize(organization, days: DAYS)
      @organization = organization
      @days = days
    end

    def to_h
      {
        active_students: active_students_series,
        session_funnel: session_funnel,
        app_open_states: app_open_states,
        totals: totals
      }
    end

    private
      attr_reader :organization, :days

      # One pass over the window's org-scoped events; every metric is derived in Ruby
      # from this, so the dashboard is a single query regardless of how many series it
      # grows. Volumes per org over a 14-day window stay small.
      def rows
        @rows ||= Ahoy::Event.for_organization(organization)
                             .where(time: window_start..)
                             .pluck(:name, :time, :properties)
      end

      def active_students_series
        by_day = Hash.new { |hash, day| hash[day] = Set.new }
        rows.each do |_name, time, props|
          student_id = props["student_id"]
          by_day[time.in_time_zone.to_date] << student_id if student_id
        end

        each_day do |day|
          { date: day.iso8601, label: day.strftime("%d/%m"), count: by_day[day].size }
        end
      end

      def session_funnel
        started   = count_named("student.session_started")
        finished  = count_named("student.session_finished")
        cancelled = count_named("student.session_cancelled")

        {
          started: started,
          finished: finished,
          cancelled: cancelled,
          completion_rate: percent(finished, started),
          abandonment_rate: percent(cancelled, started + cancelled)
        }
      end

      def app_open_states
        counts = Hash.new(0)
        rows.each do |name, _time, props|
          next unless name == "student.home_viewed"
          counts[props["entry_state"]] += 1
        end

        ENTRY_STATES.map { |state| { state: state, count: counts[state] } }
      end

      def totals
        {
          active_students: rows.filter_map { |_name, _time, props| props["student_id"] }.uniq.size,
          home_views: count_named("student.home_viewed"),
          events: rows.size
        }
      end

      def count_named(name)
        rows.count { |row_name, _time, _props| row_name == name }
      end

      def percent(numerator, denominator)
        return 0 if denominator.zero?

        (numerator * 100.0 / denominator).round
      end

      def each_day
        first_day = today - (days - 1)
        (0...days).map { |i| yield(first_day + i) }
      end

      def window_start
        @window_start ||= (today - (days - 1)).in_time_zone.beginning_of_day
      end

      def today
        @today ||= Time.zone.today
      end
  end
end
