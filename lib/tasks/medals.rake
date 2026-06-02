namespace :medals do
  desc "Award all historical medals across every student and mark them seen (idempotent launch backfill, PRD #145)"
  task backfill: :environment do
    Student.backfill_medals!
    puts "Medal backfill complete: #{StudentMedal.count} medals awarded across #{Student.count} students."
  end
end
