class Organization
  # Builds the trainer action queue payload for the dashboard: an ordered list
  # of up to 10 student rows that need attention, plus per-tag counts unaffected
  # by the cap. Rows are bottleneck-first by tag priority and dedup'd by student
  # so a student matching multiple cohorts appears once with stacked tags.
  #
  # Slice 1 wires only the +anamnesis_pending+ tag. The full priority,
  # deduplication, capping, and tiebreaker architecture is in place — adding
  # the remaining three tags is a matter of registering them in TAGS.
  class DashboardQueue
    ROW_CAP = 10

    # Bottleneck-first. The first entry has the highest priority.
    # Each entry: tag name, scope method on Student, and a callable that
    # returns the within-tag sort value (lower sorts earlier).
    TAGS = [
      { name: :anamnesis_pending, scope: :anamnesis_pending, sort_by: ->(student) { student.created_at } }
    ].freeze

    def initialize(organization)
      @organization = organization
    end

    def to_h
      { counts: build_counts, rows: build_rows }
    end

    private
      def build_counts
        TAGS.each_with_object({}) do |tag, acc|
          acc[tag[:name]] = scope_for(tag).count
        end
      end

      def build_rows
        rows_by_student_id = {}

        TAGS.each_with_index do |tag, priority|
          scope_for(tag).find_each do |student|
            row = rows_by_student_id[student.id] ||= {
              student: student,
              tags: [],
              primary_tag: tag[:name],
              primary_priority: priority,
              sort_value: tag[:sort_by].call(student)
            }
            row[:tags] << tag[:name]
          end
        end

        rows_by_student_id
          .values
          .sort_by { |row| [ row[:primary_priority], row[:sort_value] ] }
          .first(ROW_CAP)
          .map { |row| serialize_row(row) }
      end

      def serialize_row(row)
        {
          student: { id: row[:student].id, name: row[:student].name },
          tags: row[:tags],
          primary_tag: row[:primary_tag],
          sort_value: row[:sort_value]
        }
      end

      def scope_for(tag)
        @organization.students.public_send(tag[:scope])
      end
  end
end
