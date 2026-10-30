# frozen_string_literal: true
module Finance
  # Invoked only by a separately authenticated, pinned llama.cpp adapter.
  # It stores model evidence and view-only suggestions; no transaction writes.
  class RecordExtraction
    def self.call(document_version:, model_sha256:, prompt_sha256:, raw_output:, schema_version: 'm1', diagnostic_code: nil)
      raise ArgumentError, 'Document image required' unless document_version.image.attached?
      raise ArgumentError, 'Raw output must be a JSON object' unless raw_output.is_a?(Hash)
      status = raw_output['readability_status']
      status = 'processing_error' if diagnostic_code.present?
      raise ArgumentError, 'Unsupported status' unless %w[readable partially_readable unreadable processing_error].include?(status)
      tx = document_version.finance_transaction
      run = nil
      Finance::Transaction.transaction do
        run = Finance::ExtractionRun.create!(document_version: document_version,
          model_sha256: model_sha256, prompt_sha256: prompt_sha256, schema_version: schema_version,
          parse_status: status, raw_output: raw_output, diagnostic_code: diagnostic_code)
        # Do not invent normalized dates or monetary values. Each proposal is
        # copied verbatim from explicitly structured model output.
        if %w[readable partially_readable].include?(status)
          Array(raw_output['dates']).each_with_index do |item, i|
            propose(tx, run, "dates.#{i}.literal", item['literal']) if item.is_a?(Hash)
          end
          Array(raw_output['line_items']).each_with_index do |item, i|
            next unless item.is_a?(Hash)
            propose(tx, run, "line_items.#{i}.label", item['label'])
            propose(tx, run, "line_items.#{i}.amount_literal", item['amount_literal'])
          end
          Array(raw_output['financial_fields']).each_with_index do |item, i|
            next unless item.is_a?(Hash)
            propose(tx, run, "financial_fields.#{i}.label", item['label'])
            propose(tx, run, "financial_fields.#{i}.amount_literal", item['amount_literal'])
          end
          # Later schemas may explicitly include normalized_date_iso. Never
          # derive this field from date_literal using local parsing heuristics.
          if raw_output['normalized_date_iso'].present?
            propose(tx, run, 'transaction_date_iso', raw_output['normalized_date_iso'])
          end
          { 'transaction_amount_vnd' => 'transaction_amount_vnd',
            'transaction_description' => 'transaction_description',
            'transaction_tags' => 'transaction_tags' }.each do |json_key, field_key|
            propose(tx, run, field_key, raw_output[json_key])
          end
          Array(raw_output['line_items']).each_with_index do |item, i|
            propose(tx, run, "line_items.#{i}.amount_vnd", item['amount_vnd']) if item.is_a?(Hash)
          end
        end
        Finance::AuditEvent.create!(finance_transaction: tx, workspace_id: tx.workspace_id,
          actor_id: document_version.uploaded_by_id, event_type: 'ai_extraction_recorded',
          payload: { extraction_run_id: run.id, document_version_id: document_version.id,
                     status: status, model_sha256: model_sha256 })
      end
      run
    end

    def self.propose(tx, run, key, value)
      return unless value.is_a?(String) && value.present?
      Finance::FieldSuggestion.create!(finance_transaction: tx, extraction_run: run,
        field_key: key, proposed_value: value, review_status: 'pending')
    end
    private_class_method :propose
  end
end
