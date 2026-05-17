# frozen_string_literal: true

# Records that a specific PeriodizationVersion has been physically printed and
# handed to the student. One-way: a version stays printed forever once marked;
# the "undo" is to promote a new version (which is born unprinted).
class Students::Periodizations::Versions::PrintConfirmationsController < InertiaController
  before_action :load_student
  before_action :load_periodization
  before_action :load_version

  def create
    @version.mark_printed!

    redirect_to student_periodization_printable_path(@student),
                notice: "Impressão registrada."
  end

  private
    def load_student
      @student = current_organization.students.find(params[:student_id])
    end

    def load_periodization
      @periodization = @student.periodizations.find(params[:periodization_id])
    end

    def load_version
      @version = @periodization.versions.find(params[:version_id])
    end
end
