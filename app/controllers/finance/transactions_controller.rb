# frozen_string_literal: true
module Finance
  class TransactionsController < BaseController
    before_action :find_transaction!, only: %i[show edit update confirm]

    def index
      @transactions = finance_scope.order(created_at: :desc).limit(100)
    end

    def new
      kind = %w[income expense].include?(params[:kind]) ? params[:kind] : 'expense'
      @transaction = Finance::Transaction.new(kind: kind, currency_code: 'VND')
      @transaction.line_items.build(position: 0)
      @suggestions = []
    end

    def create
      attrs = transaction_params
      attrs[:kind] = 'expense' unless %w[income expense].include?(attrs[:kind])
      @transaction = finance_scope.new(attrs)
      @transaction.assign_attributes(status: 'draft', currency_code: 'VND',
        created_by_id: @finance_actor.id, entry_source: 'manual')
      Finance::Transaction.transaction do
        @transaction.save!
        audit!('transaction_draft_created', { kind: @transaction.kind })
      end
      redirect_to finance_transaction_path(@transaction), notice: 'Draft saved. Review and confirm before reporting.'
    rescue ActiveRecord::RecordInvalid
      @suggestions = []
      render :new, status: :unprocessable_entity
    end

    def show
      @versions = @transaction.document_versions.order(version_number: :desc)
      @suggestions = suggestions_for_active_version.order(created_at: :desc).limit(100)
      @latest_extraction = @transaction.active_document_version&.extraction_runs&.order(created_at: :desc)&.first
    end

    def edit
      require_draft!
      @suggestions = suggestions_for_active_version.pending.order(created_at: :desc).limit(100)
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
      Finance::Transaction.transaction do
        before = @transaction.attributes.slice('transaction_date', 'amount', 'description', 'category')
        @transaction.update!(attrs)
        after = @transaction.reload.attributes.slice(*before.keys)
        audit!('transaction_draft_edited', { before: before, after: after })
      end
      redirect_to finance_transaction_path(@transaction), notice: 'Draft updated.'
    rescue ActiveRecord::RecordInvalid
      @suggestions = suggestions_for_active_version.pending.order(created_at: :desc).limit(100)
      render :edit, status: :unprocessable_entity
    end

    def confirm
      Finance::ConfirmTransaction.call(transaction: @transaction, actor: @finance_actor,
                                       reviewed: params[:human_confirmed] == '1')
      redirect_to finance_transaction_path(@transaction), notice: 'Transaction confirmed.'
    rescue ArgumentError, ActiveRecord::RecordInvalid => e
      redirect_to finance_transaction_path(@transaction), alert: e.message
    end

    private

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

    def transaction_params
      params.require(:finance_transaction).permit(
        :kind, :transaction_date, :amount, :description, :category,
        line_items_attributes: %i[id position description amount _destroy]
      )
    end

    def audit!(event_type, payload)
      Finance::AuditEvent.create!(finance_transaction: @transaction,
        workspace_id: @finance_workspace.id, actor_id: @finance_actor.id,
        event_type: event_type, payload: payload)
    end
  end
end
