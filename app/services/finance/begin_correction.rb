# frozen_string_literal: true

module Finance
  class BeginCorrection
    def self.call(original:, actor:, reason:)
      reason = reason.to_s.strip
      raise ArgumentError, "Reason must contain 10–2000 characters" unless reason.length.between?(10, 2000)
      raise ArgumentError, "Authenticated actor required" unless actor

      Finance::Transaction.transaction do
        source = Finance::Transaction.lock.find(original.id)
        raise ArgumentError, "Only confirmed records can be corrected" unless source.confirmed?
        raise ArgumentError, "Workspace mismatch" unless actor.workspaces.exists?(id: source.workspace_id)
        if source.correction_as_original
          raise ArgumentError, "A correction already exists for this transaction"
        end

        replacement = Finance::Transaction.create!(
          workspace_id: source.workspace_id, created_by_id: actor.id,
          kind: source.kind, status: "draft", entry_source: "manual",
          currency_code: source.currency_code, transaction_date: source.transaction_date,
          amount: source.amount, description: source.description,
          category: source.category
        )
        source.line_items.order(:position).each do |line|
          copied = replacement.line_items.build(
            position: line.position, description: line.description,
            amount: line.amount, quantity: line.quantity, unit_price: line.unit_price,
            category: line.category, occurred_on: line.occurred_on,
            occurred_time: line.occurred_time, location_text: line.location_text,
            entry_source: "manual"
          )
          copied.save!
          line.line_item_tags.each do |association|
            copied.line_item_tags.create!(category_id: association.category_id)
          end
        end
        if (context = source.context)
          replacement.create_context!(
            purchase_details: context.purchase_details,
            occurred_time: context.occurred_time,
            location_text: context.location_text, recorded_by: actor, source: "manual"
          )
        end

        correction = Finance::Correction.create!(
          original_transaction: source, replacement_transaction: replacement,
          workspace_id: source.workspace_id, requested_by: actor,
          reason: reason, status: "draft"
        )
        Finance::AuditEvent.create!(
          finance_transaction: source, workspace_id: source.workspace_id, actor_id: actor.id,
          event_type: "financial_correction_requested",
          payload: { correction_id: correction.id, replacement_id: replacement.id, reason: reason }
        )
        Finance::AuditEvent.create!(
          finance_transaction: replacement, workspace_id: source.workspace_id, actor_id: actor.id,
          event_type: "correction_draft_created",
          payload: { correction_id: correction.id, original_id: source.id }
        )
        correction
      end
    end
  end
end
