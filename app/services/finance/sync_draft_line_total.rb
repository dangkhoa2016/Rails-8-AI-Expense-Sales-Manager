# frozen_string_literal: true
module Finance
  # Sync only a mutable draft, after a user-authored item change.
  # Does not run for AI suggestions or automatically confirm a transaction.
  class SyncDraftLineTotal
    def self.call(transaction:, actor:, reason:)
      raise ArgumentError, "Draft only" unless transaction.draft?
      count = transaction.line_items.count
      # Every itemized draft follows its line-item sum, including removing
      # its last item. Old confirmed records are never touched.
      total = transaction.line_items.sum(:amount)
      prior = transaction.amount
      return transaction if prior == total

      transaction.update!(amount: total)
      Finance::AuditEvent.create!(
        finance_transaction: transaction, workspace_id: transaction.workspace_id,
        actor_id: actor.id, event_type: "finance_draft_amount_synced",
        payload: { reason: reason, from: prior&.to_s("F"),
                   to: total.to_s("F"), line_items_count: count }
      )
      transaction
    end
  end
end
