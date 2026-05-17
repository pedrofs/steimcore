# Marks a PeriodizationVersion as physically printed and handed over to the
# student. The print state is one-way: once `mark_printed!` succeeds, the
# timestamp is never overwritten. The natural "undo" path is to promote a new
# version, which starts unprinted by default.
module PeriodizationVersion::Printable
  extend ActiveSupport::Concern

  def printed?
    printed_at.present?
  end

  def mark_printed!
    return if printed?

    update!(printed_at: Time.current)
  end
end
