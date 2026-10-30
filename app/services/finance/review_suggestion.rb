# frozen_string_literal: true
require 'date'
module Finance
  class ReviewSuggestion
    # The human must trigger this endpoint. No inference calls or auto-accept.
    # Raw monetary literals and line-item fields are not accepted into numeric DB fields;
    # they remain visible suggestions next to manually entered form controls.
    def self.call(suggestion:, actor:, decision:)
      raise ArgumentError, 'Authenticated reviewer required' if actor.nil?
      raise ArgumentError, 'Invalid decision' unless %w[accept reject].include?(decision)
      Finance::Transaction.transaction do
        tx = Finance::Transaction.lock.find(suggestion.finance_transaction_id)
        suggestion.lock!
        raise ArgumentError, 'Already reviewed' unless suggestion.review_status == 'pending'
        raise ArgumentError, 'Only draft data can be reviewed' unless tx.draft?
        if decision == 'accept'
          case suggestion.field_key
          when 'transaction_date_iso'
            raise ArgumentError, 'ISO calendar date required' unless suggestion.proposed_value.match?(/\A\d{4}-\d{2}-\d{2}\z/)
            date = begin
              Date.iso8601(suggestion.proposed_value)
            rescue Date::Error
              raise ArgumentError, 'AI date is not a valid calendar date'
            end
            tx.update!(transaction_date: date, entry_source: 'ai_assisted')
          else
            # Review of other labels/amount_literal acknowledges visual evidence
            # but cannot silently mutate business fields or amounts.
          end
        end
        suggestion.update!(review_status: decision == 'accept' ? 'accepted' : 'rejected',
                           reviewed_by_id: actor.id, reviewed_at: Time.current)
        Finance::AuditEvent.create!(finance_transaction: tx, workspace_id: tx.workspace_id,
          actor_id: actor.id, event_type: 'ai_field_reviewed',
          payload: { suggestion_id: suggestion.id, field_key: suggestion.field_key,
                     decision: decision, extraction_run_id: suggestion.extraction_run_id })
      end
      suggestion
    end
  end
end
