# frozen_string_literal: true

class StudentsController < InertiaController
  with_breadcrumb label: "Alunos", path: -> { students_path }

  def index
    @title = "Alunos"
    students = current_organization.students.unarchived.order(:name)

    render inertia: "students/index", props: {
      students: students.map { |student| student_summary(student) }
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

    render inertia: "students/show", props: { student: student_props(student) }
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
        :name, :age, :sex, :primary_goal, :restrictions_summary,
        :weekly_frequency, :anamnesis_md, :notes_md
      )
    end

    def student_summary(student)
      {
        id: student.id,
        name: student.name,
        primary_goal: student.primary_goal,
        weekly_frequency: student.weekly_frequency
      }
    end

    def student_props(student)
      {
        id: student.id,
        name: student.name,
        age: student.age,
        sex: student.sex,
        primary_goal: student.primary_goal,
        restrictions_summary: student.restrictions_summary,
        weekly_frequency: student.weekly_frequency,
        anamnesis_md: student.anamnesis_md,
        notes_md: student.notes_md,
        archived: student.archived?
      }
    end
end
