# The Medal family registry (ADR-0005, CONTEXT.md "Medalhas"). A pure catalog of
# the four families a Student progresses on — display metadata plus the live
# metric each tier ladder is judged against. Insert-only evaluation
# (Student::Awardable) reads `tiers` and `metric`; the Medalhas page reads the
# display fields. The stored `key` is English; `name` is the pt-BR label.
#
# Only `workouts` has a working metric in this slice (#147). The three
# cadence-dependent families (`weekly_streak`, `full_weeks`, `periodizations`)
# are listed so the page can render them locked; their `metric` returns nil
# until their slices land, and a nil metric awards nothing and renders grayscale.
module Medal
  Family = Data.define(:key, :name, :color, :unit, :tiers, :explanation) do
    # The student's live value for this family, or nil when the family has no
    # working metric yet (or, once implemented, its cadence precondition isn't
    # met). A nil metric awards nothing and renders the family locked.
    def metric(student)
      case key
      when "workouts"
        student.training_sessions.finished.count
      end
    end

    # Highest tier whose threshold +value+ reaches, or nil when below the first.
    def highest_reached_tier(value)
      return nil if value.nil?
      tiers.reverse_each.find { |tier| value >= tier }
    end
  end

  FAMILIES = [
    Family.new(
      key: "workouts",
      name: "Treinos",
      color: "#a80038",
      unit: "treinos",
      tiers: [ 1, 5, 15, 25, 50, 100, 200, 250 ],
      explanation: "Ganhe medalhas conforme você completa treinos. Cada treino finalizado conta — inclusive os que seu treinador registrou em datas passadas."
    ),
    Family.new(
      key: "weekly_streak",
      name: "Sequência semanal",
      color: "#d97706",
      unit: "semanas",
      tiers: [ 2, 4, 8, 12, 26, 52 ],
      explanation: "Semanas seguidas em que você bateu sua meta semanal. Uma semana perdida não zera a sequência; duas seguidas, sim."
    ),
    Family.new(
      key: "full_weeks",
      name: "Semanas cheias",
      color: "#0d9488",
      unit: "semanas",
      tiers: [ 1, 2, 4, 8, 12, 26, 52 ],
      explanation: "Total de semanas, ao longo de toda a sua jornada, em que você bateu sua meta semanal."
    ),
    Family.new(
      key: "periodizations",
      name: "Periodizações",
      color: "#6d28d9",
      unit: "blocos",
      tiers: [ 1, 2, 3, 4, 6, 8 ],
      explanation: "Cada periodização que você treina até o fim, completando toda a dose prescrita pelo seu treinador."
    )
  ].freeze

  class << self
    def families
      FAMILIES
    end

    def find(key)
      FAMILIES.find { |family| family.key == key }
    end
  end
end
