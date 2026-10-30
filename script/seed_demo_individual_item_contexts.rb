# frozen_string_literal: true
# Synthetic, opt-in draft for items sharing a transaction date with optional times/locations.
raise "Development demo flag required" unless Rails.env.development? && ENV["FINANCE_DEMO_PREVIEW"] == "1"
user = User.find_by(email_address: "finance.demo@example.test")
workspace = user&.workspaces&.find_by(name: "Finance Demo Workspace")
raise "Dedicated private demo workspace is missing" unless user && workspace

description = "Demo: Five receipt items with a shared transaction date and optional times"
rows = [
  ["Mua bánh mì ngọt", "30000", "08:12", "Tiệm bánh giả lập gần đồn cảnh sát Đà Nẵng", "food"],
  ["Mua sữa tươi", "42000", "08:31", "Quầy sữa giả lập, Đà Nẵng", "food"],
  ["Mua giấy A4", "85000", "13:40", "Cửa hàng văn phòng phẩm giả lập, Đà Nẵng", "office"],
  ["Gửi xe", "5000", nil, nil, "transport"],
  ["Mua bút bi", "13000", "16:20", nil, "office"]
].freeze

tx = Finance::Transaction.for_workspace(workspace.id).find_by(description: description)
if tx
  # Do not change previously edited user drafts, ever.
  raise "Unexpected duplicate or status" unless tx.draft? && tx.line_items.count == 5
  puts "PER_ITEM_DEMO_ALREADY_PRESENT draft_id=#{tx.id} lines=#{tx.line_items.count}"
else
  tx = Finance::Transaction.transaction do
    parent = workspace.finance_transactions.create!(
      kind: "expense", status: "draft", currency_code: "VND",
      entry_source: "manual", created_by_id: user.id,
      transaction_date: Date.new(2026, 4, 26),
      amount: BigDecimal("175000"), description: description
    )
    Finance::Tag.bootstrap!(workspace.id)
    rows.each_with_index do |(label, amount, time, place, tag_key), index|
      line = parent.line_items.create!(
        position: index, description: label, amount: BigDecimal(amount),
        entry_source: "manual", occurred_time: time, location_text: place
      )
      tag = Finance::Tag.for_workspace(workspace.id).find_by!(key: tag_key)
      Finance::ItemTagging.apply!(item: line, workspace_id: workspace.id,
        tag_ids: [tag.id], new_names: "")
    end
    Finance::AuditEvent.create!(
      finance_transaction: parent, workspace_id: workspace.id, actor_id: user.id,
      event_type: "synthetic_item_level_demo_created",
      payload: { line_item_count: 5, user_confirmation_required: true }
    )
    parent
  end
  puts "PER_ITEM_DEMO_PASS draft_id=#{tx.id} lines=#{tx.line_items.count} "       "total=#{tx.line_items.sum(:amount).to_s('F')} status=#{tx.status}"
end
