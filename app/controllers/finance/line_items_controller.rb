# frozen_string_literal: true
module Finance
  class LineItemsController < BaseController
    before_action :load_finance_transaction!
    before_action :require_draft!, only: %i[new create destroy import]
    before_action :find_item!, only: %i[edit update destroy]

    def index
      @count = @transaction.line_items.count
      @sum = @transaction.line_items.sum(:amount)
      @difference = @transaction.amount && @transaction.amount - @sum
      @pages = [(@count.to_f / 25).ceil, 1].max
      requested = params[:page].to_s.match?(/\A\d{1,5}\z/) ? params[:page].to_i : 1
      @page = requested.clamp(1, @pages)
      @items = @transaction.line_items.includes(:tags).order(:position, :id).offset((@page - 1) * 25).limit(25)
      @new_item = Finance::LineItem.new
    end

    def proposals
      @suggestions = @transaction.field_suggestions.joins(:extraction_run)
        .where(finance_extraction_runs: {document_version_id: @transaction.active_document_version_id})
        .where("finance_field_suggestions.field_key LIKE ?", "line_items.%")
        .order(:id).limit(1_500).to_a

      grouped = @suggestions.filter_map do |suggestion|
        match = suggestion.field_key.match(/\Aline_items\.(\d+)\.(label|amount_literal|amount_vnd)\z/)
        [match[1].to_i, suggestion] if match
      end.group_by(&:first)
      @indices = grouped.keys.sort
      @pages = [(@indices.size.to_f / 25).ceil, 1].max
      requested = params[:page].to_s.match?(/\A\d{1,5}\z/) ? params[:page].to_i : 1
      @page = requested.clamp(1, @pages)
      selected = @indices.slice((@page - 1) * 25, 25) || []
      @proposals = selected.map do |index|
        [index, grouped.fetch(index).map(&:last)]
      end
    end

    def edit
      prepare_tags!(@item)
      @line_item = @item
      @requires_correction = @transaction.confirmed?
      if @requires_correction && @transaction.correction_as_original
        redirect_to finance_transaction_line_items_path(
          @transaction.correction_as_original.replacement_transaction
        ), status: :see_other
      end
    end

    def new
      @new_item = Finance::LineItem.new(entry_source: "manual", quantity: 1)
      prepare_tags!(@new_item)
      total_pages = [(@transaction.line_items.count.to_f / 25).ceil, 1].max
      @page = requested_page(total_pages)
    end

    def create
      Finance::Transaction.transaction do
        tx = finance_scope.lock.find(@transaction.id)
        raise ArgumentError, "Draft only" unless tx.draft?
        raise ArgumentError, "Maximum 500 line items" if tx.line_items.count >= 500

        attrs = quick_item_params
        # Date is the transaction's field, not a per-item field.
        # Optional time is stored only when the user explicitly provides it.
        @new_item = tx.line_items.build(attrs.merge(
          position: (tx.line_items.maximum(:position) || -1) + 1,
          entry_source: "manual"
        ))
        @new_item.save!
        apply_tags!(@new_item)
        Finance::SyncDraftLineTotal.call(transaction: tx, actor: @finance_actor, reason: "item_created")
        audit!("finance_line_item_added", item_id: @new_item.id,
          tag_ids: @new_item.tags.pluck(:id))
      end

      @transaction.reload
      if request.format.turbo_stream?
        @count = @transaction.line_items.count
        @sum = @transaction.line_items.sum(:amount)
        @difference = @transaction.amount && @transaction.amount - @sum
        @pages = [(@count.to_f / 25).ceil, 1].max
        @page = requested_page(@pages)
        @items = @transaction.line_items.includes(:tags).order(:position, :id)
          .offset((@page - 1) * 25).limit(25)

        item_visible = @items.any? { |item| item.id == @new_item.id }
        message = I18n.t("finance.m6.saved")
        message_content = if item_visible
          message
        else
          helpers.safe_join([
            message, " ",
            helpers.link_to(I18n.t("finance.m6.view_new_item"),
              finance_transaction_line_items_path(@transaction, page: @pages,
                                                   anchor: helpers.dom_id(@new_item)))
          ])
        end

        render turbo_stream: [
          turbo_stream.replace("line_item_list",
            partial: "finance/line_items/list",
            locals: { transaction: @transaction, items: @items,
                      page: @page, pages: @pages }),
          turbo_stream.replace("line_items_summary",
            partial: "finance/line_items/summary",
            locals: { transaction: @transaction, count: @count,
                      sum: @sum, difference: @difference }),
          turbo_stream.update("line_item_modal", ""),
          turbo_stream.update("line_item_feedback", message_content)
        ]
      else
        redirect_to finance_transaction_line_items_path(@transaction,
          page: params[:page]), notice: I18n.t("finance.m6.saved"),
          status: :see_other
      end
    rescue ActiveRecord::RecordInvalid, ActiveRecord::RecordNotUnique, ArgumentError => error
      @new_item ||= Finance::LineItem.new
      @modal_error = error.message
      prepare_tags!(@new_item)
      total_pages = [(@transaction.line_items.count.to_f / 25).ceil, 1].max
      @page = requested_page(total_pages)
      if request.format.turbo_stream?
        render turbo_stream: turbo_stream.update(
          "line_item_modal", partial: "finance/line_items/new_modal",
          locals: { line_item: @new_item, transaction: @transaction,
                    page: @page, error: @modal_error }
        ), status: :unprocessable_entity
      else
        render :new, status: :unprocessable_entity
      end
    end

    def update
      if @transaction.draft?
        update_draft_item!
      elsif @transaction.confirmed?
        create_item_correction!
      else
        raise ActionController::RoutingError, "Not Found"
      end

      @transaction.reload
      if request.format.turbo_stream?
        @sum = @transaction.line_items.sum(:amount)
        @difference = @transaction.amount && @transaction.amount - @sum
        render turbo_stream: [
          turbo_stream.replace(
            helpers.dom_id(@item),
            partial: "finance/line_items/line_item_row",
            locals: { item: @item.reload, transaction: @transaction }
          ),
          turbo_stream.replace(
            "line_items_summary",
            partial: "finance/line_items/summary",
            locals: { transaction: @transaction, count: @transaction.line_items.count,
                      sum: @sum, difference: @difference }
          ),
          turbo_stream.update("line_item_modal", ""),
          turbo_stream.update("line_item_feedback",
            I18n.t(@transaction.confirmed? ? "finance.m6.correction_draft_created" : "finance.m6.saved"))
        ]
      else
        redirect_to finance_transaction_line_items_path(@transaction, page: params[:page]),
          notice: I18n.t("finance.m6.saved"), status: :see_other
      end
    rescue ActiveRecord::RecordInvalid, ActiveRecord::RecordNotUnique, ArgumentError => error
      @line_item = @item
      @requires_correction = @transaction.confirmed?
      @modal_error = error.message
      prepare_tags!(@line_item)
      if request.format.turbo_stream?
        render turbo_stream: turbo_stream.update(
          "line_item_modal", partial: "finance/line_items/modal",
          locals: { line_item: @line_item, transaction: @transaction,
                    requires_correction: @requires_correction, error: @modal_error }
        ), status: :unprocessable_entity
      else
        render :edit, status: :unprocessable_entity
      end
    end

    def update_draft_item!
      Finance::Transaction.transaction do
        locked = finance_scope.lock.find(@transaction.id)
        raise ArgumentError, "Draft only" unless locked.draft?
        @item.reload
        before = @item.attributes.slice("description", "amount", "quantity", "unit_price",
                                         "occurred_on", "occurred_time", "location_text")
        @item.update!(quick_item_params)
        apply_tags!(@item)
        Finance::SyncDraftLineTotal.call(transaction: locked, actor: @finance_actor, reason: "item_updated")
        after = @item.reload.attributes.slice(*before.keys)
        audit!("finance_line_item_updated",
          item_id: @item.id, before: before, after: after,
          tag_ids: @item.tags.pluck(:id))
      end
    end

    def create_item_correction!
      reason = params[:correction_reason].to_s.strip
      raise ArgumentError, I18n.t("finance.m6.correction_reason_required") unless reason.length.between?(10, 2000)
      Finance::Transaction.transaction do
        @transaction.reload
        raise ArgumentError, I18n.t("finance.m6.correction_already_exists") if
          @transaction.correction_as_original
        correction = Finance::BeginCorrection.call(
          original: @transaction, actor: @finance_actor, reason: reason
        )
        replacement = correction.replacement_transaction
        copied = replacement.line_items.find_by!(position: @item.position)
        before = copied.attributes.slice("description", "amount", "quantity", "unit_price",
                                          "occurred_on", "occurred_time", "location_text")
        copied.update!(quick_item_params)
        apply_tags!(copied)
        after = copied.reload.attributes.slice(*before.keys)
        Finance::AuditEvent.create!(
          finance_transaction: replacement, workspace_id: replacement.workspace_id,
          actor_id: @finance_actor.id, event_type: "correction_item_draft_edited",
          payload: { original_item_id: @item.id, copied_item_id: copied.id,
                     correction_id: correction.id, before: before, after: after,
                     tag_ids: copied.tags.pluck(:id) }
        )
      end
      @transaction.association(:correction_as_original).reset
    end

    def destroy
      Finance::Transaction.transaction do
        tx = finance_scope.lock.find(@transaction.id)
        raise ArgumentError, "Draft only" unless tx.draft?
        item_id = @item.id
        @item.destroy!
        Finance::SyncDraftLineTotal.call(transaction: tx, actor: @finance_actor, reason: "item_deleted")
        audit!("finance_line_item_removed", item_id: item_id)
      end
      redirect_to finance_transaction_line_items_path(@transaction), notice: I18n.t("finance.m6.removed")
    rescue ActiveRecord::RecordNotDestroyed, ArgumentError => e
      redirect_to finance_transaction_line_items_path(@transaction), alert: e.message
    end

    def import
      result = Finance::ImportLineItems.call(transaction: @transaction, actor: @finance_actor, upload: params[:file])
      notice = result[:status] == :already_imported ? I18n.t("finance.m6.duplicate") : I18n.t("finance.m6.imported", count: result[:rows])
      redirect_to finance_transaction_line_items_path(@transaction), notice: notice
    rescue ArgumentError, ActiveRecord::RecordInvalid, ActiveRecord::RecordNotUnique => e
      redirect_to finance_transaction_line_items_path(@transaction), alert: e.message
    end

    private

    def requested_page(total_pages)
      requested = params[:page].to_s.match?(/\A\d{1,5}\z/) ? params[:page].to_i : 1
      requested.clamp(1, total_pages)
    end

    def find_item!
      @item = @transaction.line_items.find(params[:id])
    end

    def require_draft!
      raise ActionController::RoutingError, "Not Found" unless @transaction.draft?
    end

    def item_params
      params.require(:line_item).permit(
        :description, :amount, :quantity, :unit_price,
        :occurred_time, :location_text
      )
    end

    # The UI calculates immediately. The server recomputes from submitted
    # quantity and price; no browser-supplied total is trusted when both exist.
    # CSV imports and older amount-only edits remain unchanged.
    def quick_item_params
      attrs = item_params.to_h.symbolize_keys
      if attrs[:quantity].present? && attrs[:unit_price].present?
        q = BigDecimal(attrs[:quantity].to_s)
        price = BigDecimal(attrs[:unit_price].to_s)
        raise ArgumentError, "Invalid quantity" unless q.positive?
        raise ArgumentError, "Invalid unit price" if price.negative?
        attrs[:amount] = (q * price).round(2, BigDecimal::ROUND_HALF_UP)
      end
      attrs
    rescue ArgumentError
      raise ArgumentError, I18n.t("finance.quick_item.invalid_calculation")
    end

    def apply_tags!(item)
      return unless params.dig(:line_item, :tag_selection).to_s == "1"
      Finance::ItemTagging.apply!(
        item: item, workspace_id: @transaction.workspace_id,
        tag_ids: params.dig(:line_item, :tag_ids),
        new_names: params.dig(:line_item, :new_tags)
      )
    end

    def prepare_tags!(item)
      Finance::Tag.bootstrap!(@transaction.workspace_id)
      selected = if params.dig(:line_item, :tag_selection).to_s == "1"
        Array(params.dig(:line_item, :tag_ids)).map(&:to_s)
      elsif item.persisted?
        ids = item.tags.pluck(:id).map(&:to_s)
        ids
      else
        []
      end
      @selected_tag_ids = selected
      @new_tag_names = params.dig(:line_item, :new_tags).to_s
      @available_tags = Finance::Tag.for_workspace(@transaction.workspace_id)
        .where(active: true).or(
          Finance::Tag.for_workspace(@transaction.workspace_id).where(id: selected)
        ).order(:key).to_a
    end

    def audit!(event_type, attrs)
      Finance::AuditEvent.create!(
        finance_transaction: @transaction, workspace_id: @finance_workspace.id, actor_id: @finance_actor.id,
        event_type: event_type, payload: attrs
      )
    end
  end
end
