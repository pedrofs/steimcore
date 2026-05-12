module TrainingSession::Blockable
  extend ActiveSupport::Concern

  INDEX_FORMAT = /\A\d+\z/

  included do
    validate :validate_progress_entries
  end

  def mark_block_done!(index)
    validate_index!(index)
    return if progress.include?(index)
    update!(progress: progress + [ index ])
  end

  def unmark_block!(index)
    validate_index!(index)
    return unless progress.include?(index)
    update!(progress: progress - [ index ])
  end

  def block_completed?(index)
    validate_index!(index)
    progress.include?(index)
  end

  private
    def validate_index!(index)
      raise ArgumentError, "índice de bloco inválido: #{index.inspect}" unless index.is_a?(String) && index.match?(INDEX_FORMAT)
      raise ArgumentError, "índice de bloco fora do intervalo: #{index}" if Integer(index) >= blocks_snapshot.length
    end

    def validate_progress_entries
      Array(progress).each do |entry|
        unless entry.is_a?(String) && entry.match?(INDEX_FORMAT) && Integer(entry) < blocks_snapshot.length
          errors.add(:progress, "índice inválido: #{entry.inspect}")
        end
      end
    end
end
