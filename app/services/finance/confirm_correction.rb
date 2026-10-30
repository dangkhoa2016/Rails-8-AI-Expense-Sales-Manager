# frozen_string_literal: true

module Finance
  class ConfirmCorrection
    def self.call(correction:, actor:, reviewed:)
      raise ArgumentError, "Explicit human confirmation is required" unless reviewed == true
      raise ArgumentError, "Authenticated actor required" unless actor

      Finance::Transaction.transaction do
        record = Finance::Correction.lock.find(correction.id)
        raise ArgumentError, "Correction already confirmed" unless record.draft?
        raise ArgumentError, "Workspace mismatch" unless actor.workspaces.exists?(id: record.workspace_id)
        source = Finance::Transaction.lock.find(record.original_transaction_id)
        replacement = Finance::Transaction.lock.find(record.replacement_transaction_id)
        raise ArgumentError, "Original transaction is not confirmed" unless source.confirmed?
        raise ArgumentError, "Correction replacement is not a draft" unless replacement.draft?
        raise ArgumentError, "Other correction already superseded original" if
          Finance::Correction.confirmed.where(original_transaction_id: source.id).where.not(id: record.id).exists?
        raise ArgumentError, "Transaction type or currency mismatch" unless
          source.kind == replacement.kind && source.currency_code == replacement.currency_code
        raise ArgumentError, "Workspace mismatch" unless
          source.workspace_id == record.workspace_id && replacement.workspace_id == record.workspace_id

        Finance::ConfirmTransaction.call(transaction: replacement, actor: actor, reviewed: true)
        record.update!(status: "confirmed", confirmed_by: actor, confirmed_at: Time.current)

        before = { transaction_id: source.id, date: source.transaction_date.iso8601,
                   amount: source.amount.to_s("F"), kind: source.kind }
        after = { transaction_id: replacement.id, date: replacement.transaction_date.iso8601,
                  amount: replacement.amount.to_s("F"), kind: replacement.kind }
        Finance::AuditEvent.create!(
          finance_transaction: source, workspace_id: record.workspace_id, actor_id: actor.id,
          event_type: "financial_correction_superseded",
          payload: { correction_id: record.id, before: before, after: after }
        )
        Finance::AuditEvent.create!(
          finance_transaction: replacement, workspace_id: record.workspace_id, actor_id: actor.id,
          event_type: "financial_correction_effective",
          payload: { correction_id: record.id, original_id: source.id, reason: record.reason }
        )
        record
      end
    end
  end
end
