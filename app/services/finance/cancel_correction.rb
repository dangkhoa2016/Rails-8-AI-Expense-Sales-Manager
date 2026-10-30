# frozen_string_literal: true

module Finance
  # Auditable soft delete. Neither original confirmed record nor append-only
  # history is destroyed. Cancelled replacements never appear in operational lists.
  class CancelCorrection
    def self.call(correction:, actor:, reason:)
      reason = reason.to_s.strip
      raise ArgumentError, "Reason must be 10–2000 characters" unless reason.length.between?(10, 2000)
      raise ArgumentError, "Authenticated actor required" unless actor

      Finance::Transaction.transaction do
        record = Finance::Correction.lock.find(correction.id)
        raise ArgumentError, "Only pending correction can be cancelled" unless record.draft?
        raise ArgumentError, "Workspace mismatch" unless actor.workspaces.exists?(id: record.workspace_id)
        replacement = Finance::Transaction.lock.find(record.replacement_transaction_id)
        source = Finance::Transaction.lock.find(record.original_transaction_id)
        raise ArgumentError, "Replacement is no longer an editable draft" unless replacement.draft?
        raise ArgumentError, "Source must be confirmed" unless source.confirmed?
        previous = Finance::RecordTransactionRevision.snapshot(source)
        replacement.update!(status: "cancelled")
        record.update!(status: "cancelled")
        Finance::RecordTransactionRevision.call(
          transaction: source, actor: actor, reason: reason,
          action: "correction_cancelled", before_state: previous,
          after_state: previous.merge("correction" => {
            "correction_id" => record.id, "replacement_transaction_id" => replacement.id,
            "status" => "cancelled"
          })
        )
        Finance::AuditEvent.create!(finance_transaction: source,
          workspace_id: source.workspace_id, actor_id: actor.id,
          event_type: "financial_correction_cancelled",
          payload: {correction_id: record.id, replacement_id: replacement.id, reason: reason})
        Finance::AuditEvent.create!(finance_transaction: replacement,
          workspace_id: replacement.workspace_id, actor_id: actor.id,
          event_type: "correction_draft_cancelled",
          payload: {correction_id: record.id, original_id: source.id, reason: reason})
        record
      end
    end
  end
end
