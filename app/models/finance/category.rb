# frozen_string_literal: true

module Finance
  class Category < ApplicationRecord
    self.table_name = "finance_categories"

    DEFAULTS = {
      "food" => ["Food & drinks", "Ăn uống"],
      "office" => ["Office supplies", "Văn phòng phẩm"],
      "transport" => ["Transport", "Di chuyển"],
      "maintenance" => ["Maintenance", "Bảo trì"],
      "sales" => ["Product sales", "Bán hàng"],
      "services" => ["Services", "Dịch vụ"],
      "rent" => ["Rent", "Thuê mặt bằng"],
      "utilities" => ["Utilities", "Điện nước"],
      "marketing" => ["Marketing", "Tiếp thị"],
      "other" => ["Other", "Khác"]
    }.freeze

    belongs_to :workspace
    has_many :line_item_tags, class_name: "Finance::LineItemTag",
      foreign_key: :category_id, dependent: :restrict_with_exception
    validates :workspace, presence: true
    validates :key, presence: true, length: { maximum: 50 },
      format: { with: /\A[a-z][a-z0-9_]{1,49}\z/ },
      uniqueness: { scope: :workspace_id }
    validates :name_en, :name_vi, presence: true, length: { maximum: 120 }
    before_validation :normalize_fields
    validate :key_immutable, on: :update

    scope :active, -> { where(active: true) }
    scope :for_workspace, ->(id) { where(workspace_id: id) }

    def label(locale = I18n.locale)
      locale.to_s == "vi" ? name_vi : name_en
    end

    # Explicitly seeded defaults plus preexisting legacy keys.
    # Insert-only, never overwrite/activate a category that a user edited or archived.
    def self.bootstrap!(workspace_id)
      now = Time.current
      keys = Finance::Transaction.for_workspace(workspace_id)
        .where.not(category: [nil, ""]).distinct.pluck(:category)
      keys += Finance::LineItem.joins(:finance_transaction)
        .where(finance_transactions: { workspace_id: workspace_id })
        .where.not(category: [nil, ""]).distinct.pluck(:category)
      keys = (DEFAULTS.keys + keys).uniq.select { |key| key.match?(/\A[a-z][a-z0-9_]{1,49}\z/) }
      entries = keys.map do |key|
        names = DEFAULTS[key] || [key.tr("_", " ").capitalize, key.tr("_", " ").capitalize]
        {workspace_id: workspace_id, key: key, name_en: names[0],
         name_vi: names[1], active: true, created_at: now, updated_at: now}
      end
      insert_all(entries, unique_by: :idx_finance_categories_tenant_key) if entries.any?
    end

    def used?
      line_item_tags.exists? || Finance::Transaction.for_workspace(workspace_id).where(category: key).exists? ||
        Finance::LineItem.joins(:finance_transaction)
          .where(finance_transactions: {workspace_id: workspace_id}, category: key).exists?
    end

    private

    def normalize_fields
      self.key = key.to_s.strip.downcase
      self.name_en = name_en.to_s.strip
      self.name_vi = name_vi.to_s.strip
    end

    def key_immutable
      errors.add(:key, "cannot be changed after creation") if key != key_in_database
    end
  end
end
