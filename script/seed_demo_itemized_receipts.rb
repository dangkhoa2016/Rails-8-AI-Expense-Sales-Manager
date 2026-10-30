# frozen_string_literal: true
require "csv"
require "stringio"

# Explicitly synthetic, opt-in development seed. Does not read receipt images.
raise "Demo only" unless Rails.env.development? && ENV["FINANCE_DEMO_PREVIEW"] == "1"
user = User.find_by(email_address: "finance.demo@example.test")
workspace = user&.workspaces&.find_by(name: "Finance Demo Workspace")
raise "Existing isolated demo account required" unless user && workspace

products = [
  ["Bánh mì ngọt", "food"], ["Sữa tươi", "food"], ["Trứng gà", "food"],
  ["Giấy in A4", "office"], ["Bút bi", "office"], ["Bìa hồ sơ", "office"],
  ["Túi đóng gói", "office"], ["Nước uống", "food"], ["Dây cáp sạc", "maintenance"],
  ["Phí giao hàng", "transport"]
].freeze

cases = [
  [5, "2026-05-18", "Demo: Itemized receipt with 5 items", "09:20", nil, "0"],
  [20, "2026-06-18", "Demo: Itemized receipt with 20 items", nil, "Demo store in Nha Trang", "0"],
  [50, "2026-09-18", "Demo: Itemized receipt with 50 items", "13:40", nil, "5000"],
  [100, "2026-10-28", "Demo: Itemized receipt with 100 items", "15:25", "Fictional wholesale store in Da Nang", "0"]
].freeze

results = []
cases.each do |count, date, description, clock, location, additional|
  rows = count.times.map do |i|
    label, tag_key = products[i % products.length]
    quantity = i % 3 + 1
    unit = 5_000 + (i % 9) * 2_000
    amount = quantity * unit
    [format("Demo %03d — %s", i + 1, label), amount, quantity, unit, tag_key]
  end
  sum = rows.sum { |row| row[1] }
  total = BigDecimal(sum.to_s) + BigDecimal(additional)

  existing = Finance::Transaction.for_workspace(workspace.id).find_by(description: description)
  if existing
    raise "Mismatch in existing demo receipt: #{description}" unless existing.confirmed? &&
      existing.kind == "expense" && existing.transaction_date == Date.iso8601(date) &&
      existing.amount == total && existing.line_items.count == count &&
      existing.line_items.sum(:amount) == BigDecimal(sum.to_s)
    results << "#{count}:already_seeded##{existing.id}"
    next
  end

  csv = CSV.generate do |sheet|
    sheet << %w[description amount quantity unit_price tags]
    rows.each { |row| sheet << row }
  end
  tx = nil
  Finance::Transaction.transaction do
    tx = workspace.finance_transactions.create!(
      kind: "expense", status: "draft", currency_code: "VND",
      entry_source: "manual", created_by_id: user.id,
      transaction_date: Date.iso8601(date), amount: total,
      description: description
    )
    tx.create_context!(recorded_by: user, source: "demo_seed",
      purchase_details: "Synthetic example with #{count} independent item lines; no real receipt or merchant.",
      occurred_time: clock, location_text: location)
    result = Finance::ImportLineItems.call(transaction: tx, actor: user, upload: StringIO.new(csv))
    raise "Expected manual import" unless result[:status] == :imported && result[:rows] == count
    if BigDecimal(additional).positive?
      # Synthetic adjustment: an explicitly modeled fee, never inferred from image.
      before_adjustment = tx.reload.amount
      tx.update!(amount: total)
      Finance::AuditEvent.create!(
        finance_transaction: tx, workspace_id: workspace.id, actor_id: user.id,
        event_type: "synthetic_demo_fee_added",
        payload: { from: before_adjustment.to_s("F"), to: total.to_s("F"),
                   fee: additional, human_review_required: true }
      )
    end
    Finance::ConfirmTransaction.call(transaction: tx, actor: user, reviewed: true)
  end
  results << "#{count}:created##{tx.id}"
end

puts "M6_SYNTHETIC_DEMO_PASS #{results.join(' ')}"
