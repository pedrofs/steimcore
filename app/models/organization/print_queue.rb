class Organization
  # Builds the home page's "Imprimir" card payload: active periodizations whose
  # current version is completed and unprinted, ordered oldest-first. Students
  # already surfaced by the DashboardQueue are suppressed per ADR-0001 — the
  # print card is a clean handoff list, not a duplicate of the attention queue.
  class PrintQueue
    ROW_CAP = 10

    def initialize(organization)
      @organization = organization
    end

    def to_h
      eligible = eligible_versions
      { count: eligible.size, rows: eligible.first(ROW_CAP).map { |v| serialize(v) } }
    end

    private
      def eligible_versions
        suppressed_ids = Organization::DashboardQueue.tagged_student_ids(@organization)

        scope = PeriodizationVersion
          .joins(periodization: :student)
          .where(periodizations: { archived_at: nil })
          .where("periodization_versions.id = periodizations.current_version_id")
          .where(periodization_versions: { status: "completed", printed_at: nil })
          .where(students: { organization_id: @organization.id })
          .order("periodization_versions.created_at ASC")
          .includes(periodization: :student)

        scope = scope.where.not(students: { id: suppressed_ids }) if suppressed_ids.any?
        scope.to_a
      end

      def serialize(version)
        student = version.periodization.student
        {
          student: { id: student.id, name: student.name },
          periodization: { id: version.periodization.id },
          version: { id: version.id, created_at: version.created_at }
        }
      end
  end
end
