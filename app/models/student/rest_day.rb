class Student
  # The fixed Saturday/Sunday rest-day rule for student *self-started* sessions.
  # Pure calendar logic evaluated against the app's Time.zone — there is no
  # per-student schedule. Trainer-initiated starts and resume/finish/cancel are
  # exempt; only a student self-start is blocked on weekends. See PRD #136 /
  # slice #138 and ADR-0005.
  module RestDay
    module_function

    def today?(zone: Time.zone)
      date = zone.today
      date.saturday? || date.sunday?
    end
  end
end
