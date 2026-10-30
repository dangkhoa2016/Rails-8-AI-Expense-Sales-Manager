# frozen_string_literal: true

module Finance
  class CorrectionsController < BaseController
    before_action :find_source!, only: :create

    def create
      target = @source.line_items.find(params[:line_item_id]) if params[:line_item_id].present?
      correction = Finance::BeginCorrection.call(
        original: @source, actor: @finance_actor, reason: params[:reason]
      )
      if target
        copied = correction.replacement_transaction.line_items.find_by!(position: target.position)
        redirect_to edit_finance_transaction_line_item_path(correction.replacement_transaction, copied),
          notice: I18n.t("finance.correction.created")
      else
        redirect_to finance_transaction_path(correction.replacement_transaction),
          notice: I18n.t("finance.correction.created")
      end
    rescue ArgumentError, ActiveRecord::RecordInvalid, ActiveRecord::RecordNotUnique => e
      redirect_to finance_transaction_path(@source), alert: e.message
    end

    private

    def find_source!
      @source = finance_scope.find(params[:transaction_id])
    end
  end
end
