# frozen_string_literal: true
module Finance
  class ConfirmTransaction
    def self.call(transaction:, actor:, reviewed:)
      raise ArgumentError, 'Explicit human confirmation required' unless reviewed == true
      raise ArgumentError, 'Authenticated actor required' if actor.nil?
      Finance::Transaction.transaction do
        transaction.lock!
        raise ArgumentError, 'Only drafts can be confirmed' unless transaction.draft?
        unless Finance::InputPolicy.confirmable?(date: transaction.transaction_date, amount: transaction.amount,
                                                  actor_id: actor.id, human_confirmed: reviewed)
          raise ArgumentError, 'Confirmed date and positive amount required'
        end
        # Financial AI suggestions never mutate this value. Human-reviewed line items
        # may differ from receipt totals (VAT/discount); do not reconstruct totals.
        transaction.update!(status: 'confirmed', confirmed_by_id: actor.id,
                            confirmed_at: Time.current)
        Finance::AuditEvent.create!(finance_transaction: transaction,
          workspace_id: transaction.workspace_id, actor_id: actor.id,
          event_type: 'transaction_confirmed',
          payload: { transaction_date: transaction.transaction_date.iso8601,
                     amount: transaction.amount.to_s('F'), currency: transaction.currency_code,
                     kind: transaction.kind, document_version_id: transaction.active_document_version_id })
      end
      transaction
    end
  end
end
