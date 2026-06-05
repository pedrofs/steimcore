require "test_helper"

class ExerciseTest < ActiveSupport::TestCase
  test "an exercise owns its own canonical name as a primary alias" do
    exercise = Exercise.create!(name: "Rosca direta")

    primary = exercise.aliases.find_by(normalized_key: "rosca direta")
    assert primary, "expected a primary alias for the canonical name"
    assert_equal "primary", primary.source
    assert_equal "Rosca direta", primary.raw_name
  end

  test "resolve returns the exercise for case/accent/whitespace variants of an alias" do
    exercise = Exercise.create!(name: "Supino reto")

    assert_equal exercise, Exercise.resolve("  SUPÍNO   reto ")
    assert_equal exercise, Exercise.resolve("supino reto")
  end

  test "resolve returns nil for an unknown name" do
    Exercise.create!(name: "Supino reto")

    assert_nil Exercise.resolve("Movimento que não existe")
  end

  test "resolve returns nil for blank input" do
    assert_nil Exercise.resolve("   ")
    assert_nil Exercise.resolve(nil)
  end

  test "a new exercise defaults to the unenriched state" do
    assert_predicate Exercise.create!(name: "Leg press"), :unenriched?
  end

  test "the unique constraint forbids two aliases sharing a normalized key" do
    Exercise.create!(name: "Leg press") # primary alias key "leg press"
    other = Exercise.create!(name: "Leg press 45")

    dup = other.aliases.build(raw_name: "Leg press", normalized_key: "leg press", source: "llm")
    assert_raises(ActiveRecord::RecordNotUnique) { dup.save!(validate: false) }
  end

  test "exercise_family and muscle_group are optional on mint" do
    exercise = Exercise.create!(name: "Stiff")

    assert_nil exercise.exercise_family
    assert_nil exercise.muscle_group
  end

  test "enrich attaches media and flips the exercise to enriched" do
    exercise = Exercise.create!(name: "Supino reto")

    exercise.enrich(media: [ { io: StringIO.new("png"), filename: "a.png", content_type: "image/png" } ])

    assert_predicate exercise.reload, :enriched?
    assert exercise.media.attached?
  end

  test "enrich without media stores taxonomy but leaves the exercise unenriched" do
    family = Exercise::Family.create!(name: "Supino", normalized_key: "supino")
    muscle = Exercise::MuscleGroup.create!(name: "Peito", normalized_key: "peito")
    exercise = Exercise.create!(name: "Supino reto")

    exercise.enrich(exercise_family: family, muscle_group: muscle)

    assert_predicate exercise.reload, :unenriched?
    assert_equal family, exercise.exercise_family
    assert_equal muscle, exercise.muscle_group
  end

  test "enrich enqueues video optimization when a video is attached" do
    exercise = Exercise.create!(name: "Agachamento")

    assert_enqueued_jobs 1, only: TranscodeExerciseMediaJob do
      exercise.enrich(media: [ { io: StringIO.new("raw"), filename: "clip.mov", content_type: "video/quicktime" } ])
    end
  end

  test "enrich does not enqueue optimization for image-only uploads" do
    exercise = Exercise.create!(name: "Agachamento")

    assert_enqueued_jobs 0, only: TranscodeExerciseMediaJob do
      exercise.enrich(media: [ { io: StringIO.new("png"), filename: "a.png", content_type: "image/png" } ])
    end
  end

  test "transcode_pending_media! optimizes pending videos but skips images and optimized videos" do
    exercise = Exercise.create!(name: "Agachamento")
    exercise.media.attach(io: StringIO.new("png"), filename: "a.png", content_type: "image/png")
    exercise.media.attach(io: StringIO.new("raw"), filename: "clip.mov", content_type: "video/quicktime")
    exercise.media.attach(io: StringIO.new("done"), filename: "old.mov", content_type: "video/quicktime")
    exercise.media.attachments.find { |a| a.filename.to_s == "old.mov" }
      .blob.update!(metadata: { "transcode_status" => "done" })

    optimized = []
    Exercise::MediaTranscoder.stub(:call, ->(attachment) { optimized << attachment.filename.to_s }) do
      exercise.transcode_pending_media!
    end

    assert_equal [ "clip.mov" ], optimized
  end

  test "enrich keeps an already-enriched exercise enriched when only taxonomy changes" do
    exercise = Exercise.create!(name: "Supino reto")
    exercise.enrich(media: [ { io: StringIO.new("png"), filename: "a.png", content_type: "image/png" } ])

    exercise.enrich(exercise_family: Exercise::Family.for_name("Supino"))

    assert_predicate exercise.reload, :enriched?
    assert_equal "Supino", exercise.exercise_family.name
  end

  test "enrich_taxonomy! fills empty taxonomy slots from the Enricher and stays unenriched" do
    exercise = Exercise.create!(name: "Cadeira extensora")

    Exercise::Enricher.stub(:classify, { family: "Cadeira extensora", muscle_group: "Quadríceps" }) do
      exercise.enrich_taxonomy!
    end

    exercise.reload
    assert_equal "Cadeira extensora", exercise.exercise_family.name
    assert_equal "Quadríceps", exercise.muscle_group.name
    assert_predicate exercise, :unenriched?, "taxonomy alone must not flip the state"
  end

  test "enrich_taxonomy! reuses existing taxonomy nodes by normalized key" do
    family = Exercise::Family.create!(name: "Agachamento", normalized_key: "agachamento")
    muscle = Exercise::MuscleGroup.create!(name: "Quadríceps", normalized_key: "quadriceps")
    exercise = Exercise.create!(name: "Agachamento livre")

    Exercise::Enricher.stub(:classify, { family: "agachamento", muscle_group: "QUADRÍCEPS" }) do
      exercise.enrich_taxonomy!
    end

    exercise.reload
    assert_equal family, exercise.exercise_family
    assert_equal muscle, exercise.muscle_group
  end

  test "enrich_taxonomy! is a no-op when both taxonomy slots are already set" do
    exercise = Exercise.create!(name: "Supino reto",
      exercise_family: Exercise::Family.for_name("Supino"),
      muscle_group: Exercise::MuscleGroup.for_name("Peito"))

    called = false
    Exercise::Enricher.stub(:classify, ->(_ex) { called = true; {} }) do
      exercise.enrich_taxonomy!
    end

    assert_not called, "Enricher must not run when taxonomy is already complete"
  end

  test "enrich_taxonomy! preserves an already-set slot and fills only the missing one" do
    family = Exercise::Family.for_name("Supino")
    exercise = Exercise.create!(name: "Supino reto", exercise_family: family)

    Exercise::Enricher.stub(:classify, { family: "Outra family", muscle_group: "Peito" }) do
      exercise.enrich_taxonomy!
    end

    exercise.reload
    assert_equal family, exercise.exercise_family, "an already-set slot must not be clobbered"
    assert_equal "Peito", exercise.muscle_group.name
  end

  test "unclassified selects only unenriched exercises with an empty taxonomy slot" do
    Exercise.create!(name: "Supino reto",
      exercise_family: Exercise::Family.for_name("Supino"),
      muscle_group: Exercise::MuscleGroup.for_name("Peito")) # fully classified — excluded
    missing_muscle = Exercise.create!(name: "Agachamento", exercise_family: Exercise::Family.for_name("Agachamento"))
    blank = Exercise.create!(name: "Stiff")

    assert_equal [ blank.id, missing_muscle.id ].sort, Exercise.unclassified.pluck(:id).sort
  end

  test "enrich_unclassified_later enqueues one job per unclassified exercise" do
    Exercise.create!(name: "Supino reto",
      exercise_family: Exercise::Family.for_name("Supino"),
      muscle_group: Exercise::MuscleGroup.for_name("Peito")) # fully classified — skipped
    Exercise.create!(name: "Agachamento", exercise_family: Exercise::Family.for_name("Agachamento"))
    Exercise.create!(name: "Stiff")

    assert_enqueued_jobs 2, only: EnrichExerciseJob do
      Exercise.enrich_unclassified_later
    end
  end

  test "merge_into! repoints the loser's aliases onto the target and records merged_into" do
    survivor = Exercise.create!(name: "Supino reto")
    loser = Exercise.create!(name: "Supino reto com barra")
    loser.aliases.create!(raw_name: "supino barra", normalized_key: "supino barra", source: "llm")

    loser.merge_into!(survivor)

    assert_equal survivor, loser.reload.merged_into
    assert_empty loser.aliases.reload
    repointed = survivor.aliases.reload.map(&:normalized_key)
    assert_includes repointed, "supino reto com barra"
    assert_includes repointed, "supino barra"
  end

  test "after merge_into! names that resolved to the loser resolve to the survivor" do
    survivor = Exercise.create!(name: "Supino reto")
    loser = Exercise.create!(name: "Supino reto com barra")

    loser.merge_into!(survivor)

    assert_equal survivor, Exercise.resolve("Supino reto com barra")
    assert_equal survivor, Exercise.resolve("supíno reto") # survivor's own name still resolves
  end

  test "merge_into! preserves the alias unique key — no duplicate-key violation" do
    survivor = Exercise.create!(name: "Supino reto")
    loser = Exercise.create!(name: "Supino inclinado")

    assert_nothing_raised { loser.merge_into!(survivor) }
    keys = survivor.aliases.reload.map(&:normalized_key)
    assert_equal keys.uniq, keys
  end

  test "merge_into! refuses to merge an exercise into itself" do
    exercise = Exercise.create!(name: "Supino reto")

    assert_raises(ArgumentError) { exercise.merge_into!(exercise) }
    assert_nil exercise.reload.merged_into
  end

  test "merge_into! flattens chains — merging the survivor again repoints inherited aliases" do
    a = Exercise.create!(name: "Supino reto")
    b = Exercise.create!(name: "Supino reto com barra")
    c = Exercise.create!(name: "Supino")

    b.merge_into!(a)
    a.merge_into!(c)

    assert_equal c, Exercise.resolve("Supino reto com barra")
    assert_equal c, Exercise.resolve("Supino reto")
  end

  test "attach_media! attaches one clip, flips to enriched, and leaves taxonomy untouched" do
    family = Exercise::Family.for_name("Supino")
    muscle = Exercise::MuscleGroup.for_name("Peito")
    exercise = Exercise.create!(name: "Supino reto", exercise_family: family, muscle_group: muscle)

    exercise.attach_media!({ io: StringIO.new("png"), filename: "a.png", content_type: "image/png" })

    exercise.reload
    assert_predicate exercise, :enriched?
    assert exercise.media.attached?
    assert_equal family, exercise.exercise_family, "taxonomy must survive a media-only capture"
    assert_equal muscle, exercise.muscle_group
  end

  test "attach_media! enqueues video optimization for a captured video clip" do
    exercise = Exercise.create!(name: "Agachamento")

    assert_enqueued_jobs 1, only: TranscodeExerciseMediaJob do
      exercise.attach_media!({ io: StringIO.new("raw"), filename: "clip.mov", content_type: "video/quicktime" })
    end
  end

  test "attach_media! does not enqueue optimization for a captured photo" do
    exercise = Exercise.create!(name: "Agachamento")

    assert_enqueued_jobs 0, only: TranscodeExerciseMediaJob do
      exercise.attach_media!({ io: StringIO.new("png"), filename: "a.png", content_type: "image/png" })
    end
  end
end
