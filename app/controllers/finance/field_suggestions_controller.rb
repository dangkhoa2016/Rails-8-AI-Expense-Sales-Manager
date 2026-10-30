# frozen_string_literal: true
module Finance
  class FieldSuggestionsController < BaseController
    before_action :load_finance_transaction!
    before_action :find_suggestion!

    def accept
      Finance::ReviewSuggestion.call(suggestion: @suggestion, actor: @finance_actor, decision: 'accept')
      redirect_to review_destination, notice: I18n.t('finance.flash.suggestion_reviewed')
    rescue ArgumentError, ActiveRecord::RecordInvalid => e
      redirect_to review_destination, alert: e.message
    end

    def reject
      Finance::ReviewSuggestion.call(suggestion: @suggestion, actor: @finance_actor, decision: 'reject')
      redirect_to review_destination, notice: I18n.t('finance.flash.suggestion_rejected')
    rescue ArgumentError, ActiveRecord::RecordInvalid => e
      redirect_to review_destination, alert: e.message
    end

    private
    def review_destination
      if params[:scope] == "line_items"
        proposals_finance_transaction_line_items_path(@transaction, page: params[:page])
      else
        edit_finance_transaction_path(@transaction)
      end
    end

    def find_suggestion!
      @suggestion = @transaction.field_suggestions.find(params[:id])
    end
  end
end
