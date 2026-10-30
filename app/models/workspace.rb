class Workspace < ApplicationRecord
  belongs_to :owner, class_name: "User"
  has_many :finance_transactions, class_name: "Finance::Transaction", foreign_key: :workspace_id, dependent: :restrict_with_exception
  has_many :finance_categories, class_name: "Finance::Category",
    foreign_key: :workspace_id, dependent: :restrict_with_exception
  validates :name, presence: true, length: { maximum: 120 }
end
