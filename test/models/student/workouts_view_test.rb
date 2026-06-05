require "test_helper"

class Student::WorkoutsViewTest < ActiveSupport::TestCase
  setup do
    @student = students(:alice)
    @trainer = users(:one)
  end

  test "lists the current version's workouts in prescribed position order" do
    build_active_plan!

    workouts = Student::WorkoutsView.new(@student.reload).to_h[:workouts]

    assert_equal [ "Treino A", "Treino B" ], workouts.map { |w| w[:name] }
    assert_equal [ 1, 2 ], workouts.map { |w| w[:position] }
  end

  test "each workout payload carries id, name, position and blocks" do
    plan = build_active_plan!
    treino_a = plan[:version].workouts.find_by(position: 1)

    payload = Student::WorkoutsView.new(@student.reload).to_h[:workouts].first

    assert_equal treino_a.id, payload[:id]
    assert_equal "Treino A", payload[:name]
    assert_equal 1, payload[:position]
    assert_equal(
      [ { "kind" => "exercise", "name" => "Supino", "prescription" => "4x10", "media" => [] } ],
      payload[:blocks]
    )
  end

  test "exercise blocks across workouts carry resolved media from the catalog" do
    build_active_plan!
    supino = Exercise.create!(name: "Supino")
    photo = attach_photo(supino)

    workouts = Student::WorkoutsView.new(@student.reload).to_h[:workouts]

    enriched = workouts.find { |w| w[:name] == "Treino A" }[:blocks].first
    assert_equal 1, enriched["media"].size
    assert_equal photo.id, enriched["media"][0][:id]

    # An unenriched exercise on another workout still renders, with no media.
    plain = workouts.find { |w| w[:name] == "Treino B" }[:blocks].first
    assert_equal [], plain["media"]
  end

  test "the media resolve does not fan out per workout (no N+1 across the tab)" do
    exercise = Exercise.create!(name: "Supino")
    attach_photo(exercise)

    build_plan_with_workout_count!(2)
    few = count_queries { Student::WorkoutsView.new(@student.reload).to_h }

    @student.update!(active_periodization: nil)
    build_plan_with_workout_count!(20)
    many = count_queries { Student::WorkoutsView.new(@student.reload).to_h }

    assert_equal few, many, "ten times the workouts must not multiply the media resolve queries"
  end

  test "returns an empty list when the student has no active periodization" do
    assert_equal [], Student::WorkoutsView.new(@student).to_h[:workouts]
  end

  test "returns an empty list when the active periodization has no promoted current version" do
    periodization = @student.periodizations.create!
    periodization.versions.create!(trainer: @trainer, status: "generating")
    @student.update!(active_periodization: periodization)

    assert_equal [], Student::WorkoutsView.new(@student.reload).to_h[:workouts]
  end

  test "returns an empty list when the current version has zero workouts" do
    periodization = @student.periodizations.create!
    version = periodization.versions.create!(trainer: @trainer, status: "completed", periodization_length_weeks: 8)
    periodization.set_current_version!(version)
    @student.update!(active_periodization: periodization)

    assert_equal [], Student::WorkoutsView.new(@student.reload).to_h[:workouts]
  end

  test "shows only the promoted current version, not superseded or draft versions" do
    plan = build_active_plan!
    # A newer draft forked off the current version carries different workouts but
    # is not promoted; the student must not see it.
    draft = plan[:periodization].versions.create!(
      trainer: @trainer, status: "completed", periodization_length_weeks: 8, parent_version: plan[:version]
    )
    draft.workouts.create!(name: "Treino Secreto", position: 1, blocks: [])

    workouts = Student::WorkoutsView.new(@student.reload).to_h[:workouts]

    assert_equal [ "Treino A", "Treino B" ], workouts.map { |w| w[:name] }
    assert_not_includes workouts.map { |w| w[:name] }, "Treino Secreto"
  end

  private
    def build_active_plan!
      periodization = @student.periodizations.create!
      version = periodization.versions.create!(trainer: @trainer, status: "completed", periodization_length_weeks: 8)
      version.workouts.create!(name: "Treino A", position: 1, blocks: [
        { "kind" => "exercise", "name" => "Supino", "prescription" => "4x10" }
      ])
      version.workouts.create!(name: "Treino B", position: 2, blocks: [
        { "kind" => "exercise", "name" => "Agachamento", "prescription" => "4x8" }
      ])
      periodization.set_current_version!(version)
      @student.update!(active_periodization: periodization)
      { periodization: periodization, version: version }
    end

    def build_plan_with_workout_count!(count)
      periodization = @student.periodizations.create!
      version = periodization.versions.create!(trainer: @trainer, status: "completed", periodization_length_weeks: 8)
      count.times do |i|
        version.workouts.create!(name: "Treino #{i + 1}", position: i + 1, blocks: [
          { "kind" => "exercise", "name" => "Supino", "prescription" => "4x10" }
        ])
      end
      periodization.set_current_version!(version)
      @student.update!(active_periodization: periodization)
    end

    def attach_photo(exercise)
      exercise.media.attach(io: StringIO.new("png-bytes"), filename: "photo.png", content_type: "image/png")
      exercise.media.attachments.last
    end

    def count_queries(&block)
      count = 0
      counter = lambda do |_name, _start, _finish, _id, payload|
        next if payload[:name] == "SCHEMA"
        next if payload[:sql] =~ /\A\s*(BEGIN|COMMIT|RELEASE|SAVEPOINT|ROLLBACK)/i
        count += 1
      end
      ActiveSupport::Notifications.subscribed(counter, "sql.active_record", &block)
      count
    end
end
