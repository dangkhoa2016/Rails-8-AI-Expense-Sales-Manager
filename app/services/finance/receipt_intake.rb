# frozen_string_literal: true

module Finance
  # Upload-first intake. Creates an unconfirmed, amount-free draft and records
  # the actual receipt bytes, not an OCR-derived or guessed financial field.
  # The extraction adapter is not invoked here; inference must be explicitly
  # connected and independently audited before its proposals can appear.
  class ReceiptIntake
    def self.call(workspace:, actor:, upload:, kind: "expense")
      raise ArgumentError, "Unsupported transaction kind" unless %w[expense income].include?(kind)
      raise ArgumentError, "Receipt image required" if upload.blank?

      transaction = nil
      version = nil
      Finance::Transaction.transaction do
        transaction = Finance::Transaction.create!(
          workspace_id: workspace.id, created_by_id: actor.id,
          kind: kind, status: "draft", currency_code: "VND",
          line_total_managed: true,
          entry_source: "manual"
        )
        version = Finance::UploadDocument.call(
          transaction: transaction, upload: upload, actor: actor
        )
        Finance::AuditEvent.create!(
          finance_transaction: transaction, workspace_id: workspace.id,
          actor_id: actor.id, event_type: "receipt_first_draft_created",
          payload: { document_version_id: version.id, kind: kind,
                     ai_inference_invoked: false, human_review_required: true }
        )
      end
      [transaction, version]
    end
  end
end
