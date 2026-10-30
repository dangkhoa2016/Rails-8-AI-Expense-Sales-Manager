class EnforceFinanceWorkspaceFk < ActiveRecord::Migration[8.0]
  def change
    add_foreign_key :finance_transactions, :workspaces, column: :workspace_id
  end
end
