# frozen_string_literal: true

module Finance
  # Snapshot only user-maintained financial fields, context and line items.
  # Append-only DB trigger protects all committed revisions from update/delete.
  # Caller MUST hold a row lock on transaction while recording a new version.
  class RecordTransactionRevision
    def self.snapshot(transaction)
      tx = transaction.reload
      {
        "transaction" => {
          "kind" => tx.kind,
          "transaction_date" => tx.transaction_date&.iso8601,
          "amount" => tx.amount&.to_s("F"),
          "description" => tx.description,
          "category" => tx.category,
          "status" => tx.status
        },
        "context" => if (context = tx.context)
          {
            "purchase_details" => context.purchase_details,
            "occurred_time" => context.occurred_time&.strftime("%H:%M"),
            "location_text" => context.location_text
          }
        else
          nil
        end,
        "line_items" => tx.line_items.includes(:tags).order(:position, :id).map do |item|
          {
            "id" => item.id, "position" => item.position,
            "description" => item.description, "amount" => item.amount&.to_s("F"),
            "quantity" => item.quantity&.to_s("F"),
            "unit_price" => item.unit_price&.to_s("F"),
            "category" => item.category, "occurred_time" => item.occurred_time&.strftime("%H:%M"),
            "location_text" => item.location_text, "tag_keys" => item.tags.map(&:key).sort
          }
        end
      }
    end

    def self.call(transaction:, actor:, reason:, action:, before_state:, after_state:)
      reason = reason.to_s.strip
      raise ArgumentError, "Revision reason must be 10–2000 characters" unless reason.length.between?(10, 2000)
      raise ArgumentError, "Workspace mismatch" unless actor.workspaces.exists?(id: transaction.workspace_id)
      changed = before_state.keys.union(after_state.keys).each_with_object({}) do |key, hash|
        next if before_state[key] == after_state[key]
        hash[key] = { "before" => before_state[key], "after" => after_state[key] }
      end
      return nil if changed.empty?
      number = transaction.revisions.maximum(:version_number).to_i + 1
      transaction.revisions.create!(
        workspace_id: transaction.workspace_id, actor_id: actor.id,
        version_number: number, action: action, reason: reason,
        before_state: before_state, after_state: after_state, change_set: changed
      )
    end
  end
end
