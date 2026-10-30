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

  def category_label(value)
    key = "finance.category.#{value}"
    I18n.exists?(key, I18n.locale) ? I18n.t(key) : value.presence || ui("reports.category.uncategorized")
  end

  def locale_switch_url(target)
    query = request.query_parameters.slice("month", "status", "kind", "q", "page")
    query["locale"] = target
    "#{request.path}?#{query.to_query}"
  end
end
