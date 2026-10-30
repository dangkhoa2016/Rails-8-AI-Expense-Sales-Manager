# frozen_string_literal: true
module Finance
  # Pure domain policy: a document may be unreadable without being an invalid file.
  class InputPolicy
    STATES = %w[readable partially_readable unreadable processing_error invalid_file].freeze

    def self.ui_mode(status)
      case status
      when 'readable', 'partially_readable' then :review_ai_fields_or_manual
      when 'unreadable' then :manual_entry_or_better_image
      when 'processing_error' then :retry_or_manual
      when 'invalid_file' then :upload_supported_file_or_manual
      else :unknown_status
      end
    end

    def self.confirmable?(date:, amount:, actor_id:, human_confirmed:)
      return false unless human_confirmed && date && actor_id
      return false unless amount && amount.respond_to?(:positive?) && amount.positive?
      true
    end

    def self.reportable?(status:) = status == 'confirmed'
    def self.auto_post_from_ai? = false
  end
end
