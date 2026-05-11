# frozen_string_literal: true

# Trainer review queue. Renders three groups of voice-recording-driven rows
# (failed, ready, in_flight) for the current trainer; the page polls every few
# seconds to reflect status progression. Personal scope only for now; org scope
# arrives in a later slice.
class InboxesController < InertiaController
  def show
    @title = "Inbox"
    add_breadcrumb(label: "Inbox", path: inbox_path)

    groups = Inbox.new(trainer: Current.user).groups

    render inertia: "inbox/show", props: {
      groups: {
        failed: groups[:failed].map { |row| row.to_h },
        ready: groups[:ready].map { |row| row.to_h },
        in_flight: groups[:in_flight].map { |row| row.to_h }
      }
    }
  end
end
