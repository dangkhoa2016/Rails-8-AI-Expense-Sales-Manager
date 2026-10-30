# frozen_string_literal: true
module Finance
  class BaseController < ApplicationController
    before_action :require_finance_identity!

    private

    def require_finance_identity!
      # MUST use the host app's authenticated/authorized current_workspace and user.
      unless respond_to?(:current_workspace, true) && respond_to?(:current_user, true) &&
             current_workspace&.id && current_user&.id
        raise ActionController::RoutingError, 'Not Found'
      end
      @finance_workspace = current_workspace
      @finance_actor = current_user
    end

    def finance_scope
      Finance::Transaction.for_workspace(@finance_workspace.id)
    end

    def load_finance_transaction!
      @transaction = finance_scope.find(params[:transaction_id] || params[:id])
    end
  end
end
