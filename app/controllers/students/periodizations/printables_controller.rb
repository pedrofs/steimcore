# frozen_string_literal: true

# Chrome-free printable view of a student's active periodization. The browser
# auto-fires its native print dialog on load (via document.fonts.ready +
# window.print() in the React component); this controller's job is to gather
# the student/periodization/version props and render them through a layout
# that strips the app navbar/sidebar/flash so the on-screen preview matches
# what hits the paper.
class Students::Periodizations::PrintablesController < InertiaController
  layout "application_print"

  before_action :load_student
  before_action :load_active_periodization
  before_action :ensure_version_completed

  def show
    render inertia: "students/periodizations/printables/show", props: {
      student: student_props,
      organization: { name: @student.organization.name },
      periodization: periodization_props
    }
  end

  private
    def load_student
      @student = current_organization.students.find(params[:student_id])
    end

    def load_active_periodization
      @periodization = @student.active_periodization
      @version = @periodization&.current_version
    end

    def ensure_version_completed
      if @periodization.nil?
        redirect_to student_path(@student),
                    alert: "Não há uma periodização ativa pronta para imprimir."
      elsif @version.nil? || @version.status != "completed"
        redirect_to student_periodization_path(@student, @periodization),
                    alert: "A versão atual ainda não está pronta para imprimir."
      end
    end

    def student_props
      {
        id: @student.id,
        name: @student.name,
        age: @student.age,
        sex: @student.sex,
        primary_goal: @student.primary_goal,
        weekly_frequency: @student.weekly_frequency,
        restrictions_summary: @student.restrictions_summary
      }
    end

    def periodization_props
      {
        id: @periodization.id,
        started_on: @periodization.created_at.to_date.iso8601,
        body_md: @version.body_md,
        version: {
          id: @version.id,
          printed_at: @version.printed_at&.iso8601
        },
        workouts: @version.workouts.order(:position).map { |w|
          { id: w.id, name: w.name, position: w.position, blocks: w.blocks }
        }
      }
    end
end
