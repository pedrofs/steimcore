class DefaultPeriodizationLengthWeeksToEight < ActiveRecord::Migration[8.2]
  # 8 weeks is the default mesocycle length the LLM tends to land on and the
  # value trainers expect when they don't override it. Defaulting the column
  # (and backfilling nulls) lets the show page render a sensible target the
  # moment a version is created — before the LLM has answered — and removes
  # the null state from the periodization_length_weeks read path for in-flight
  # versions. The column stays nullable because ADR 0002's contract still
  # holds at the schema level (presence is enforced on :completed by the
  # model validation), but in practice it should now always carry a value.
  def up
    change_column_default :periodization_versions, :periodization_length_weeks, from: nil, to: 8
    PeriodizationVersion.where(periodization_length_weeks: nil).update_all(periodization_length_weeks: 8)
  end

  def down
    change_column_default :periodization_versions, :periodization_length_weeks, from: 8, to: nil
  end
end
