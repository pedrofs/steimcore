# Pure-Ruby schema validator for the JSONB +blocks+ column on Workout. Walks the
# tree and returns an array of pt-BR error strings. Accepts both string- and
# symbol-keyed hashes (the column hands back string keys, but in-process patches
# come through with symbol keys before save).
#
# Block schema (3-kind discriminated union):
#   exercise — { kind, name, prescription, [rest_s], [notes] }
#   group    — { kind, [label], [rounds], items: [{ name, prescription, [notes] }] }
#   freeform — { kind, text_md }
class Workout
  module Blocks
    KINDS = %w[exercise group freeform].freeze

    module_function

    def errors_for(value)
      return [ "blocos devem ser uma lista" ] unless value.is_a?(Array)

      errors = []
      value.each_with_index do |block, index|
        errors.concat(errors_for_block(block, index))
      end
      errors
    end

    def valid?(value)
      errors_for(value).empty?
    end

    class << self
      private

      def errors_for_block(block, index)
        prefix = "bloco #{index}"
        return [ "#{prefix}: deve ser um objeto" ] unless block.is_a?(Hash)

        kind = fetch(block, :kind)
        return [ "#{prefix}: campo kind ausente" ] if kind.nil?
        return [ "#{prefix}: kind desconhecido (#{kind.inspect})" ] unless KINDS.include?(kind)

        case kind
        when "exercise" then errors_for_exercise(block, prefix)
        when "group"    then errors_for_group(block, prefix)
        when "freeform" then errors_for_freeform(block, prefix)
        end
      end

      def errors_for_exercise(block, prefix)
        errors = []
        errors << "#{prefix}: name ausente ou vazio" unless non_empty_string?(fetch(block, :name))
        errors << "#{prefix}: prescription ausente ou vazia" unless non_empty_string?(fetch(block, :prescription))

        rest_s = fetch(block, :rest_s)
        errors << "#{prefix}: rest_s deve ser inteiro" if rest_s && !rest_s.is_a?(Integer)

        notes = fetch(block, :notes)
        errors << "#{prefix}: notes deve ser string" if notes && !notes.is_a?(String)
        errors
      end

      def errors_for_group(block, prefix)
        errors = []
        label = fetch(block, :label)
        errors << "#{prefix}: label deve ser string" if label && !label.is_a?(String)

        rounds = fetch(block, :rounds)
        errors << "#{prefix}: rounds deve ser inteiro" if rounds && !rounds.is_a?(Integer)

        items = fetch(block, :items)
        unless items.is_a?(Array)
          errors << "#{prefix}: items ausentes ou inválidos (lista esperada)"
          return errors
        end

        items.each_with_index do |item, item_index|
          item_prefix = "#{prefix}.items[#{item_index}]"
          unless item.is_a?(Hash)
            errors << "#{item_prefix}: deve ser um objeto"
            next
          end
          errors << "#{item_prefix}: name ausente ou vazio" unless non_empty_string?(fetch(item, :name))
          errors << "#{item_prefix}: prescription ausente ou vazia" unless non_empty_string?(fetch(item, :prescription))

          notes = fetch(item, :notes)
          errors << "#{item_prefix}: notes deve ser string" if notes && !notes.is_a?(String)
        end
        errors
      end

      def errors_for_freeform(block, prefix)
        text = fetch(block, :text_md)
        return [ "#{prefix}: text_md ausente" ] if text.nil?
        return [ "#{prefix}: text_md deve ser string" ] unless text.is_a?(String)
        []
      end

      def fetch(hash, key)
        hash[key.to_s] || hash[key.to_sym]
      end

      def non_empty_string?(value)
        value.is_a?(String) && !value.strip.empty?
      end
    end
  end
end
