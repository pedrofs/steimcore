# frozen_string_literal: true

class StudentsController < InertiaController
  with_breadcrumb label: "Alunos", path: -> { students_path }

  rescue_from Pagy::OverflowError, with: :redirect_to_last_page

  def index
    @title = "Alunos"
    filters = index_filters
    scope = filtered_students(filters)
    @pagy, students = pagy(scope, limit: 25)

    render inertia: "students/index", props: {
      students: students.map { |student| student_summary(student) },
      pagination: pagination_props(@pagy),
      filters: filters,
      invitation_summary: invitation_summary
    }
  end

  def new
    @title = "Novo aluno"
    add_breadcrumb(label: "Novo", path: new_student_path)

    render inertia: "students/new"
  end

  def create
    student = current_organization.students.new(create_params)

    if student.save
      redirect_to student_path(student), notice: "Aluno cadastrado."
    else
      redirect_to new_student_path,
                  inertia: { errors: student.errors.to_hash(true) }
    end
  end

  def show
    student = current_organization.students.find(params[:id])
    @title = student.name
    add_breadcrumb(label: student.name, path: student_path(student))

    render inertia: "students/show", props: {
      student: student_props(student),
      frequency: frequency_props(student),
      invitation: invitation_props(student),
      medals: medals_props(student),
      templates: templates_props
    }
  end

  def edit
    student = current_organization.students.find(params[:id])
    @title = "Editar #{student.name}"
    add_breadcrumb(label: student.name, path: student_path(student))
    add_breadcrumb(label: "Editar", path: edit_student_path(student))

    render inertia: "students/edit", props: { student: student_props(student) }
  end

  def update
    student = current_organization.students.find(params[:id])

    if student.update(update_params)
      redirect_to student_path(student), notice: "Aluno atualizado."
    else
      redirect_to edit_student_path(student),
                  inertia: { errors: student.errors.to_hash(true) }
    end
  end

  private
    def create_params
      params.require(:student).permit(:name)
    end

    def update_params
      params.require(:student).permit(
        :name, :birthday, :sex, :primary_goal,
        :weekly_frequency, :phone, :email, :anamnesis_md, :notes_md
      )
    end

    # Counts surfaced above the roster so the trainer sees onboarding progress
    # and what the bulk "Convidar todos" button will actually do before clicking.
    def invitation_summary
      unarchived = current_organization.students.unarchived
      {
        eligible: StudentIdentity.pending_for_organization(current_organization).off_cooldown.count,
        no_email: unarchived.where(email: [ nil, "" ]).count,
        confirmed: unarchived.joins(:student_identity)
                             .merge(StudentIdentity.confirmed).distinct.count
      }
    end

    # Per-student invite state for the show page. nil hides the control entirely
    # (archived, no email, or already confirmed); otherwise the frontend renders
    # an enabled "Convidar" button or a disabled cooldown state.
    def invitation_props(student)
      identity = student.student_identity
      return nil if student.archived? || student.email.blank?
      return nil if identity.nil? || identity.confirmed?

      {
        invitable: identity.invitable?,
        last_invited_at: identity.last_invited_at&.iso8601,
        cooldown_available_at: identity.cooldown_available_at&.iso8601
      }
    end

    def student_summary(student)
      {
        id: student.id,
        name: student.name,
        primary_goal: student.primary_goal,
        weekly_frequency: student.weekly_frequency,
        active_periodization_id: student.active_periodization_id,
        archived: student.archived?,
        archive_reason: student.archive_reason
      }
    end

    STATUS_SCOPES = {
      "plan_needs_action"     => :plan_needs_action,
      "periodization_overdue" => :periodization_overdue,
      "periodization_due"     => :periodization_due,
      "inactive"              => :inactive,
      "anamnesis_pending"     => :anamnesis_pending,
      "no_plan"               => :without_active_plan
    }.freeze
    KNOWN_STATUSES = STATUS_SCOPES.keys.freeze

    def index_filters
      explicit_status = params[:status] if KNOWN_STATUSES.include?(params[:status])
      legacy_without_active = params[:without_active] == "1"

      # DEPRECATED: ?without_active=1 is a silent alias for ?status=no_plan,
      # preserved for one release window so existing bookmarks keep working.
      # Remove once external consumers have migrated.
      resolved_status = explicit_status || (legacy_without_active ? "no_plan" : nil)

      {
        q: params[:q].to_s,
        without_active: legacy_without_active,
        archived: params[:archived] == "1",
        status: resolved_status
      }
    end

    def filtered_students(filters)
      scope = filters[:archived] ? current_organization.students.archived : current_organization.students.unarchived

      if filters[:q].present?
        like = "%#{ActiveRecord::Base.sanitize_sql_like(filters[:q])}%"
        scope = scope.where("name ILIKE ?", like)
      end

      scope = scope.merge(Student.public_send(STATUS_SCOPES.fetch(filters[:status]))) if filters[:status]

      scope.order(:name)
    end

    def pagination_props(pagy)
      {
        page: pagy.page,
        pages: pagy.pages,
        count: pagy.count,
        from: pagy.from,
        to: pagy.to,
        prev: pagy.prev,
        next: pagy.next,
        series: pagy.series
      }
    end

    def redirect_to_last_page(exception)
      redirect_to url_for(request.query_parameters.merge(page: exception.pagy.last))
    end

    def student_props(student)
      {
        id: student.id,
        name: student.name,
        age: student.age,
        birthday: student.birthday&.iso8601,
        sex: student.sex,
        primary_goal: student.primary_goal,
        weekly_frequency: student.weekly_frequency,
        phone: student.phone,
        email: student.email,
        anamnesis_md: student.anamnesis_md,
        notes_md: student.notes_md,
        archived: student.archived?,
        archived_at: student.archived_at&.iso8601,
        archive_reason: student.archive_reason,
        active_periodization_id: student.active_periodization_id,
        active_plan: active_plan_props(student)
      }
    end

    def frequency_props(student)
      return nil if student.archived?
      Student::FrequencyView.new(student).to_h
    end

    # The org's reusable Periodization templates, offered on the plan hero card
    # as "Começar a partir de um modelo" when the student has no active plan.
    # Empty when the org has no templates yet, which hides the affordance.
    def templates_props
      current_organization.periodization_templates.order(:name).map do |template|
        { id: template.id, name: template.name, description: template.description }
      end
    end

    # The student's Earned medals as a passive, read-only list for the trainer
    # profile (PRD #145, slice 5) — newest achievement first. Reading never
    # touches seen_at and never celebrates; the seen lifecycle belongs solely to
    # the student's own Medalhas page. Each entry carries what the Medal
    # component needs to render plus the earned date.
    def medals_props(student)
      student.student_medals.order(earned_at: :desc, id: :desc).filter_map do |medal|
        family = Medal.find(medal.family)
        next if family.nil?

        {
          id: medal.id,
          family: family.key,
          name: family.name,
          color: family.color,
          unit: family.unit,
          count: medal.tier,
          tier_index: family.tiers.index(medal.tier) || 0,
          tier_count: family.tiers.length,
          earned_at: medal.earned_at&.iso8601
        }
      end
    end

    def active_plan_props(student)
      periodization = student.active_periodization
      return nil if periodization.nil?

      version = periodization.current_version
      workouts_count = version&.workouts&.count || 0
      next_workout = TrainingSession.next_workout_for(student)
      last_finished = student.training_sessions.finished.order(finished_at: :desc).first
      active_session = student.training_sessions.active.first

      {
        periodization_id: periodization.id,
        version_status: version&.status,
        next_workout: next_workout && {
          name: next_workout.name,
          position: next_workout.position,
          total: workouts_count
        },
        last_session_at: last_finished&.finished_at&.iso8601,
        active_session_id: active_session&.id
      }
    end
end
