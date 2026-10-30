class CreateWorkspaces < ActiveRecord::Migration[8.0]
  def change
    create_table :workspaces do |t|
      t.references :owner, null: false, foreign_key: { to_table: :users }, index: true
      t.string :name, null: false, limit: 120
      t.timestamps
    end
  end
end
