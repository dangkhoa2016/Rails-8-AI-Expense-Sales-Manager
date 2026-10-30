# frozen_string_literal: true

module Finance
  # Workspace-scoped tag assignment for manually edited DRAFT line items.
  # Existing finance_categories are reused as localized tag labels.
  # 'category' stays the primary, once-counted reporting key (never a multi-allocation).
  class ItemTagging
    MAX_TAGS = 12
    MAX_NEW_NAMES = 6

    def self.apply!(item:, workspace_id:, tag_ids:, new_names:)
      raise ArgumentError, "Draft transaction required" unless item.finance_transaction.draft?
      raise ArgumentError, "Workspace mismatch" unless item.finance_transaction.workspace_id == workspace_id

      ids = Array(tag_ids).reject(&:blank?).map do |value|
        raise ArgumentError, "Invalid tag ID" unless value.to_s.match?(/\A[1-9]\d*\z/)
        value.to_i
      end.uniq
      raise ArgumentError, "Too many tags (max 12)" if ids.length > MAX_TAGS
      by_id = Finance::Category.for_workspace(workspace_id).where(id: ids).index_by(&:id)
      raise ArgumentError, "Unknown workspace tag" unless by_id.size == ids.size
      tags = ids.map { |id| by_id.fetch(id) }
      unless tags.all? { |tag| tag.active? || item.tags.exists?(id: tag.id) }
        raise ArgumentError, "Archived tags cannot be added to new items"
      end

      names = new_names.to_s.split(/[,\n]/).map(&:strip).reject(&:blank?).uniq
      raise ArgumentError, "Too many new tags (max 6)" if names.length > MAX_NEW_NAMES
      names.each do |name|
        raise ArgumentError, "Tag name must be between 2 and 80 characters" unless name.length.between?(2, 80)
        tag = Finance::Category.for_workspace(workspace_id).where(active: true)
          .where("lower(name_en) = lower(?) OR lower(name_vi) = lower(?)", name, name).first
        unless tag
          slug = name.parameterize(separator: "_").gsub(/[^a-z0-9_]/, "")
          slug = "tag" if slug.blank?
          slug = "tag_#{slug}" unless slug.match?(/\A[a-z]/)
          slug = slug.first(40)
          slug = "tag_#{slug}" if slug.length < 2
          key = slug
          index = 2
          while Finance::Category.for_workspace(workspace_id).exists?(key: key)
            key = "#{slug.first(40)}_#{index}"
            index += 1
          end
          # A newly created name is user-written, not machine-translated:
          # both locales initially show it until the owner edits either translation.
          tag = Finance::Category.create!(
            workspace_id: workspace_id, key: key, name_en: name, name_vi: name, active: true
          )
        end
        tags << tag
      end
      tags = tags.uniq(&:id)
      raise ArgumentError, "Too many tags (max 12)" if tags.length > MAX_TAGS

      item.line_item_tags.where.not(category_id: tags.map(&:id)).destroy_all
      existing = item.line_item_tags.pluck(:category_id)
      tags.each do |tag|
        item.line_item_tags.create!(category: tag) unless existing.include?(tag.id)
      end

      # Preserve the transaction's accounting total and report-once semantics.
      # If tags are provided, the first is the legacy primary category; secondary
      # tags never duplicate the amount in reporting.
      item.update!(category: tags.first&.key)
      tags
    end
  end
end
