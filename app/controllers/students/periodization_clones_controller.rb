# frozen_string_literal: true

# Clones a Periodization template into a student as a live, promoted plan — no
# AI (PRD #170/#173). The noun produced is a clone, so this is its own
# sub-resource (CLAUDE.md: RESTful-only, no verb actions). Both the student and
# the template are org-scoped, so a trainer can neither clone into another org's
# student nor clone another org's template. After cloning, the trainer lands on
# the student's now-promoted plan so they can immediately tweak it.
class Students::PeriodizationClonesController < InertiaController
  before_action :load_student
  before_action :load_template

  def create
    periodization = @student.start_periodization_from_template!(@template, trainer: Current.user)

    redirect_to student_periodization_path(@student, periodization),
                notice: "Periodização criada a partir do modelo."
  end

  private
    def load_student
      @student = current_organization.students.find(params[:student_id])
    end

    def load_template
      @template = current_organization.periodization_templates.find(params[:template_id])
    end
end
