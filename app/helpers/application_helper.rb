module ApplicationHelper
  def ui(key, **values)
    I18n.t("finance.#{key}", **values)
  end

  def money_vnd(value, unit: true)
    return ui("shared.unknown") if value.nil?
    decimal = BigDecimal(value.to_s)
    parts = decimal.abs.to_s("F").split(".")
    whole = number_with_delimiter(parts.first, delimiter: I18n.locale == :vi ? "." : ",")
    cents = parts.fetch(1, "").ljust(2, "0").slice(0, 2)
    number = "#{decimal.negative? ? '-' : ''}#{whole}#{cents == '00' ? '' : (I18n.locale == :vi ? ',' : '.') + cents}"
    unit ? "#{number} ₫" : number
  end

  def human_day(date)
    date ? date.strftime("%d/%m/%Y") : ui("shared.unknown")
  end

  def human_month(date)
    I18n.locale == :vi ? date.strftime("%m/%Y") : date.strftime("%B %Y")
  end

  def category_catalog
    return {} unless respond_to?(:current_workspace) && current_workspace
    @category_catalog ||= Finance::Category.for_workspace(current_workspace.id)
      .map { |category| [category.key, category] }.to_h
  end

  def category_label(value)
    return ui("reports.category.uncategorized") if value.blank?
    return category_catalog[value].label if category_catalog.key?(value)
    key = "finance.category.#{value}"
    I18n.exists?(key, I18n.locale) ? I18n.t(key) : value
  end

  def category_options(selected: nil)
    return [] unless current_workspace
    Finance::Category.bootstrap!(current_workspace.id)
    @category_catalog = nil
    categories = Finance::Category.for_workspace(current_workspace.id).active
      .order(:key).map { |category| [category.label, category.key] }
    if selected.present? && categories.none? { |entry| entry.last == selected }
      categories << [category_label(selected), selected]
    end
    categories
  end

  def locale_switch_url(target)
    query = request.query_parameters.slice("month", "status", "kind", "q", "page")
    query["locale"] = target
    "#{request.path}?#{query.to_query}"
  end
end
