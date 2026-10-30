# frozen_string_literal: true

module Finance
  # Same multi-tag UX as individual items. First tag remains the legacy
  # reporting category; secondary labels do not multiply any financial sums.
  class TransactionTagging
    def self.apply!(transaction:, actor:, tag_ids:, new_names:)
      raise ArgumentError, "Editable draft required" unless transaction.draft?
      raise ArgumentError, "Workspace mismatch" unless actor.workspaces.exists?(id: transaction.workspace_id)

      ids = Array(tag_ids).reject(&:blank?).map do |value|
        raise ArgumentError, "Invalid Tag ID" unless value.to_s.match?(/\A[1-9]\d*\z/)
        value.to_i
      end.uniq
      raise ArgumentError, "Too many tags" if ids.size > Finance::ItemTagging::MAX_TAGS
      selected = Finance::Category.for_workspace(transaction.workspace_id).where(id: ids).index_by(&:id)
      raise ArgumentError, "Tag does not exist in this workspace" unless selected.size == ids.size
      if selected.values.any? { |tag| !tag.active? && !transaction.tags.exists?(id: tag.id) }
        raise ArgumentError, "Archived Tags cannot be added"
      end

      names = new_names.to_s.split(/[,\n]/).map(&:strip).reject(&:blank?).uniq
      raise ArgumentError, "Too many new tags" if names.size > Finance::ItemTagging::MAX_NEW_NAMES
      tags = ids.map { |id| selected.fetch(id) }
      names.each do |name|
        raise ArgumentError, "Tag name must contain 2–80 characters" unless name.length.between?(2, 80)
        tag = Finance::Category.for_workspace(transaction.workspace_id).active
          .where("lower(name_vi) = lower(?) OR lower(name_en) = lower(?)", name, name).first
        unless tag
          slug = name.parameterize(separator: "_").gsub(/[^a-z0-9_]/, "")
          slug = "tag" if slug.blank?
          slug = "tag_#{slug}" unless slug.match?(/\A[a-z]/)
          slug = slug.first(40)
          slug = "tag_#{slug}" if slug.length < 2
          key = slug
          suffix = 2
          while Finance::Category.for_workspace(transaction.workspace_id).exists?(key: key)
            key = "#{slug.first(40)}_#{suffix}"
            suffix += 1
          end
          tag = Finance::Category.create!(
            workspace_id: transaction.workspace_id, key: key,
            name_vi: name, name_en: name, active: true
          )
        end
        tags << tag
      end
      tags.uniq!(&:id)
      raise ArgumentError, "Too many tags" if tags.size > Finance::ItemTagging::MAX_TAGS
      transaction.transaction_tags.where.not(category_id: tags.map(&:id)).destroy_all
      existing = transaction.transaction_tags.pluck(:category_id)
      tags.each do |tag|
        transaction.transaction_tags.create!(category: tag) unless existing.include?(tag.id)
      end
      transaction.update!(category: tags.first&.key)
      tags
    end
  end
end
