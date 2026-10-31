# frozen_string_literal: true
module Finance
  class TransactionsController < BaseController
    before_action :find_transaction!, only: %i[show edit update confirm review]

    def index
      scope = finance_scope.where.not(status: "cancelled")
      @date_range = Finance::DateRangeFilter.for_params(params, default: "all")
      @tag_filter = Finance::TagFilter.for_params(params, workspace: @finance_workspace)
      scope = @tag_filter.apply(scope)
      @draft_count = scope.where(status: 'draft').count
      today = Time.find_zone!("Asia/Ho_Chi_Minh").today
      kpi_period = @date_range.range || (today.beginning_of_month..today.end_of_month)
      @kpi_period_label = @date_range.active? ?
        "#{I18n.l(kpi_period.begin, format: :short)} – #{I18n.l(kpi_period.end, format: :short)}" :
        nil
      totals = scope.effective_confirmed.where(transaction_date: kpi_period).group(:kind).sum(:amount)
      @month_income = totals.fetch('income', BigDecimal('0'))
      @month_expense = totals.fetch('expense', BigDecimal('0'))
      @month_net = @month_income - @month_expense

      @selected_status = %w[draft confirmed].include?(params[:status]) ? params[:status] : ''
      @selected_kind = %w[income expense].include?(params[:kind]) ? params[:kind] : ''
      @query = params[:q].to_s.strip.slice(0, 80)
      scope = scope.where(transaction_date: @date_range.range) if @date_range.active?
      scope = scope.where(status: @selected_status) if @selected_status.present?
      scope = scope.where(kind: @selected_kind) if @selected_kind.present?
      scope = scope.where('description ILIKE ?', "%#{ActiveRecord::Base.sanitize_sql_like(@query)}%") if @query.present?
      @filtered_count = scope.count
      @per_page = 20
      @pages = [(@filtered_count.to_f / @per_page).ceil, 1].max
      requested_page = params[:page].to_s.match?(/\A[0-9]{1,6}\z/) ? params[:page].to_i : 1
      @page = requested_page.clamp(1, @pages)
      @transactions = scope.includes(:document_versions, :context, :tags).order(created_at: :desc, id: :desc)
                           .offset((@page - 1) * @per_page).limit(@per_page)
      @superseded_transaction_ids = Finance::Correction.confirmed
        .where(original_transaction_id: @transactions.map(&:id)).pluck(:original_transaction_id).to_set
    end

    def new
      kind = %w[income expense].include?(params[:kind]) ? params[:kind] : 'expense'
      @transaction = Finance::Transaction.new(kind: kind, currency_code: 'VND')
      @transaction.build_context
      @suggestions = []
      prepare_transaction_tags!
    end

    def from_receipt
      upload = params.require(:receipt).require(:image)
      requested_kind = params.dig(:receipt, :kind).presence || "expense"
      transaction, version = Finance::ReceiptIntake.call(
        workspace: @finance_workspace, actor: @finance_actor,
        upload: upload, kind: requested_kind
      )
      redirect_to review_finance_transaction_path(transaction),
        notice: I18n.t("finance.intake.saved")
    rescue ActionController::ParameterMissing, ArgumentError, ActiveRecord::RecordInvalid => error
      redirect_to new_finance_transaction_path(kind: params.dig(:receipt, :kind)),
        alert: error.message, status: :see_other
    end

    def review
      require_draft!
      prepare_review!
      prepare_transaction_tags!
    end

    def create
      attrs = transaction_params
      first_amount = attrs.delete(:amount)
      attrs[:kind] = 'expense' unless %w[income expense].include?(attrs[:kind])
      @transaction = finance_scope.new(attrs)
      @transaction.assign_attributes(status: 'draft', currency_code: 'VND',
        amount: nil, line_total_managed: true,
        created_by_id: @finance_actor.id, entry_source: 'manual')
      if @transaction.context
        @transaction.context.recorded_by = @finance_actor
        @transaction.context.source = 'manual'
      end
      numeric_amount = BigDecimal(first_amount.to_s, exception: false)
      if first_amount.present? && (!numeric_amount || numeric_amount.negative?)
        @transaction.errors.add(:amount, I18n.t("finance.new_ux.income_amount_required"))
      end
      if params[:entry_mode] == "quick_income" && @transaction.kind == "income"
        @transaction.errors.add(:amount, I18n.t("finance.new_ux.income_amount_required")) unless
          numeric_amount&.positive?
        @transaction.errors.add(:transaction_date, I18n.t("finance.new_ux.income_date_required")) unless
          @transaction.transaction_date.present?
        @transaction.errors.add(:description, I18n.t("finance.new_ux.income_source_required")) if
          @transaction.description.blank?
        raise ActiveRecord::RecordInvalid, @transaction if @transaction.errors.any?
      end
      raise ActiveRecord::RecordInvalid, @transaction if @transaction.errors.any?
      Finance::Transaction.transaction do
        @transaction.save!
        if numeric_amount&.positive? && @transaction.line_items.empty?
          @transaction.line_items.create!(
            position: 0,
            description: @transaction.description.presence || I18n.t("finance.transaction_total.first_item"),
            amount: numeric_amount,
            entry_source: "manual"
          )
        end
        if params[:transaction_tag_selection].to_s == "1"
          apply_transaction_tags!
        end
        Finance::SyncDraftLineTotal.call(transaction: @transaction, actor: @finance_actor, reason: "initial_items_created") if
          @transaction.line_items.exists?
        audit!('transaction_draft_created', {kind: @transaction.kind, initial_items: @transaction.line_items.count})
      end
      target = params[:entry_mode] == "quick_income" && @transaction.kind == "income" ?
        review_finance_transaction_path(@transaction) : finance_transaction_path(@transaction)
      redirect_to target, notice: I18n.t('finance.flash.draft_created')
    rescue ActiveRecord::RecordInvalid
      @transaction.kind = "income" if params[:entry_mode] == "quick_income"
      @suggestions = []
      prepare_transaction_tags!
      render :new, status: :unprocessable_entity
    end

    def show
      @correction_outgoing = @transaction.correction_as_original
      @correction_incoming = @transaction.correction_as_replacement
      @comparison_source = @correction_incoming&.original_transaction
      @comparison = if @comparison_source
        Finance::CompareTransactions.call(original: @comparison_source, replacement: @transaction)
      end
      @line_items_count = @transaction.line_items.count
      @line_items_total = @transaction.line_items.sum(:amount)
      @line_items_delta = @transaction.amount && (@transaction.amount - @line_items_total)
      @versions = @transaction.document_versions.order(version_number: :desc)
      @suggestions = suggestions_for_active_version.order(created_at: :desc).limit(100)
      @latest_extraction = @transaction.active_document_version&.extraction_runs&.order(created_at: :desc)&.first
      @revisions = @transaction.revisions.includes(:actor).order(version_number: :desc).limit(40)
    end

    def edit
      require_draft!
      @correction_incoming = @transaction.correction_as_replacement
      @comparison_source = @correction_incoming&.original_transaction
      @comparison = Finance::CompareTransactions.call(original: @comparison_source, replacement: @transaction) if @comparison_source
      prepare_transaction_tags!
      @transaction.build_context unless @transaction.context
      @suggestions = suggestions_for_active_version.pending.order(created_at: :desc).limit(100)
      @large_line_item_collection = @transaction.line_items.size > 10
      if @transaction.line_items.empty?
        indexes = @suggestions.filter_map { |s| s.field_key[/\Aline_items\.(\d+)\./, 1]&.to_i }.uniq.sort.first(20)
        if indexes.any?
          indexes.each do |index|
            label = @suggestions.find { |s| s.field_key == "line_items.#{index}.label" && s.review_status == 'pending' }
            amount = @suggestions.find { |s| s.field_key == "line_items.#{index}.amount_vnd" && s.review_status == 'pending' }
            @transaction.line_items.build(position: index, description: label&.proposed_value, amount: amount&.proposed_value)
          end
        else
          @transaction.line_items.build(position: 0)
        end
      end
    end

    def update
      require_draft!
      attrs = transaction_params.except(:kind)
      attrs.delete(:amount) if @transaction.line_total_managed? || @transaction.line_items.exists?
      reason = params[:revision_reason].to_s.strip
      if !reason.length.between?(10, 2000)
        @transaction.errors.add(:base, I18n.t("finance.revisions.reason_required"))
        raise ActiveRecord::RecordInvalid, @transaction
      end

      Finance::Transaction.transaction do
        @transaction.lock!
        raise ArgumentError, I18n.t("finance.revisions.stale") if
          params.dig(:finance_transaction, :lock_version).present? &&
          params.dig(:finance_transaction, :lock_version).to_i != @transaction.lock_version
        before = Finance::RecordTransactionRevision.snapshot(@transaction)
        @transaction.assign_attributes(attrs)
        if @transaction.context&.new_record?
          @transaction.context.recorded_by = @finance_actor
          @transaction.context.source = 'manual'
        end
        @transaction.save!
        apply_transaction_tags! if params[:transaction_tag_selection].to_s == "1"
        if @transaction.line_items.exists?
          Finance::SyncDraftLineTotal.call(transaction: @transaction,
            actor: @finance_actor, reason: "transaction_header_edited")
        end
        after = Finance::RecordTransactionRevision.snapshot(@transaction)
        revision = Finance::RecordTransactionRevision.call(
          transaction: @transaction, actor: @finance_actor, reason: reason,
          action: "draft_edited", before_state: before, after_state: after
        )
        audit!('transaction_draft_edited',
          { revision_id: revision&.id, version: revision&.version_number,
            changes: revision&.change_set || {}, reason: reason }) if revision
      end
      target = params[:return_to_review] == "1" ?
        review_finance_transaction_path(@transaction) : finance_transaction_path(@transaction)
      redirect_to target, notice: I18n.t('finance.flash.draft_updated')
    rescue ActiveRecord::RecordInvalid, ArgumentError => error
      @transaction.errors.add(:base, error.message) if @transaction.errors.empty?
      if params[:return_to_review] == "1"
        prepare_review!
        prepare_transaction_tags!
        render :review, status: :unprocessable_entity
      else
        @transaction.build_context unless @transaction.context
        @correction_incoming = @transaction.correction_as_replacement
        @comparison_source = @correction_incoming&.original_transaction
        @comparison = Finance::CompareTransactions.call(original: @comparison_source, replacement: @transaction) if @comparison_source
        prepare_transaction_tags!
        @suggestions = suggestions_for_active_version.pending.order(created_at: :desc).limit(100)
        render :edit, status: :unprocessable_entity
      end
    end

    def confirm
      if (correction = @transaction.correction_as_replacement)
        Finance::ConfirmCorrection.call(correction: correction, actor: @finance_actor,
          reviewed: params[:human_confirmed] == '1')
      else
        Finance::ConfirmTransaction.call(transaction: @transaction, actor: @finance_actor,
                                         reviewed: params[:human_confirmed] == '1')
      end
      redirect_to finance_transaction_path(@transaction), notice: I18n.t('finance.flash.confirmed')
    rescue ArgumentError, ActiveRecord::RecordInvalid => e
      redirect_to finance_transaction_path(@transaction), alert: e.message
    end

    private

    def prepare_review!
      @transaction.build_context unless @transaction.context
      @version = @transaction.active_document_version
      @suggestions = suggestions_for_active_version.order(:id).limit(200)
      @item_count = @transaction.line_items.count
      @line_total = @transaction.line_items.sum(:amount)
    end

    def find_transaction!
      @transaction = finance_scope.find(params[:id])
    end

    def suggestions_for_active_version
      @transaction.field_suggestions.joins(:extraction_run).includes(:extraction_run)
        .where(finance_extraction_runs: { document_version_id: @transaction.active_document_version_id })
    end

    def require_draft!
      raise ActionController::RoutingError, 'Not Found' unless @transaction.draft?
    end

    def prepare_transaction_tags!
      Finance::Tag.bootstrap!(@finance_workspace.id)
      selected = if params[:transaction_tag_selection].to_s == "1"
        Array(params[:transaction_tag_ids]).map(&:to_s)
      else
        @transaction.tags.pluck(:id).map(&:to_s)
      end
      @selected_transaction_tag_ids = selected
      @new_transaction_tag_names = params[:transaction_new_tags].to_s
      @available_transaction_tags = Finance::Tag.for_workspace(@finance_workspace.id)
        .where(active: true).or(
          Finance::Tag.for_workspace(@finance_workspace.id).where(id: selected)
        ).order(:key).to_a
    end

    def apply_transaction_tags!
      Finance::TransactionTagging.apply!(transaction: @transaction, actor: @finance_actor,
        tag_ids: params[:transaction_tag_ids], new_names: params[:transaction_new_tags])
    end

    def transaction_params
      params.require(:finance_transaction).permit(
        :kind, :transaction_date, :amount, :description,
        context_attributes: %i[purchase_details occurred_time location_text],
        line_items_attributes: %i[id position description amount quantity unit_price occurred_time location_text _destroy]
      )
    end

    def audit!(event_type, payload)
      Finance::AuditEvent.create!(finance_transaction: @transaction,
        workspace_id: @finance_workspace.id, actor_id: @finance_actor.id,
        event_type: event_type, payload: payload)
    end
  end
end
