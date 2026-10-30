# frozen_string_literal: true

module Finance
  class Tag < ApplicationRecord
    self.table_name = "finance_tags"

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
      foreign_key: :tag_id, dependent: :restrict_with_exception
    has_many :transaction_tags, class_name: "Finance::TransactionTag",
      foreign_key: :tag_id, dependent: :restrict_with_exception
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

    # Only insert baseline Tags. Existing tenant Tags are never overwritten.
    def self.bootstrap!(workspace_id)
      now = Time.current
      entries = DEFAULTS.map do |key, names|
        {workspace_id: workspace_id, key: key, name_en: names[0],
         name_vi: names[1], active: true, created_at: now, updated_at: now}
      end
      insert_all(entries, unique_by: :idx_finance_tags_tenant_key)
    end

    def used?
      line_item_tags.exists? || transaction_tags.exists?
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
