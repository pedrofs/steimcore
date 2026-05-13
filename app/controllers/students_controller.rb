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
      filters: filters
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
      frequency: frequency_props(student)
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
        :name, :birthday, :sex, :primary_goal, :restrictions_summary,
        :weekly_frequency, :phone, :email, :anamnesis_md, :notes_md
      )
    end

    def student_summary(student)
      {
        id: student.id,
        name: student.name,
        primary_goal: student.primary_goal,
        weekly_frequency: student.weekly_frequency,
        active_periodization_id: student.active_periodization_id
      }
    end

    def index_filters
      {
        q: params[:q].to_s,
        without_active: params[:without_active] == "1",
        archived: params[:archived] == "1"
      }
    end

    def filtered_students(filters)
      scope = filters[:archived] ? current_organization.students.archived : current_organization.students.unarchived

      if filters[:q].present?
        like = "%#{ActiveRecord::Base.sanitize_sql_like(filters[:q])}%"
        scope = scope.where("name ILIKE ?", like)
      end

      scope = scope.where(active_periodization_id: nil) if filters[:without_active]

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
        restrictions_summary: student.restrictions_summary,
        weekly_frequency: student.weekly_frequency,
        phone: student.phone,
        email: student.email,
        anamnesis_md: student.anamnesis_md,
        notes_md: student.notes_md,
        archived: student.archived?,
        archived_at: student.archived_at&.iso8601,
        active_periodization_id: student.active_periodization_id,
        active_plan: active_plan_props(student)
      }
    end

    def frequency_props(student)
      return nil if student.archived?
      Student::FrequencyView.new(student).to_h
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
