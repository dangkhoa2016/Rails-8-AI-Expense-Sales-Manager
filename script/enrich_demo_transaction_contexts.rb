# frozen_string_literal: true
# Opt-in, non-production, explicitly synthetic context samples for existing demo records.
# It never updates a confirmed financial transaction or an existing context record.
raise "Demo preview flag is mandatory" unless ENV["FINANCE_DEMO_PREVIEW"] == "1"
raise "Only development permits demo seeding" unless Rails.env.development?

user = User.find_by(email_address: "finance.demo@example.test")
workspace = user&.workspaces&.find_by(name: "Finance Demo Workspace")
raise "Existing dedicated demo user/workspace required" unless user && workspace

# [date, verified-original amount, detailed purpose, optional time, optional place]
# Every purpose and place is fictional demo content, not an observed receipt.
samples = {
  "Customer payment – demo" => ["2026-10-02", 2_750_000, "Demo: khách thanh toán đơn hàng sách, đồ dùng học tập và văn phòng phẩm.", "09:30", "Quầy bán hàng mẫu tại Đà Nẵng"],
  "Office materials – demo" => ["2026-10-05", 420_000, "Demo: mua 3 hộp bút, giấy ghi chú và bìa đựng hồ sơ.", "10:05", "Cửa hàng văn phòng phẩm mẫu tại Nha Trang"],
  "Transport – demo" => ["2026-10-09", 168_000, "Demo: thanh toán chuyến taxi đến điểm giao hàng.", "16:40", nil],
  "Consulting service – demo" => ["2026-10-17", 1_800_000, "Demo: khách thanh toán buổi tư vấn công nghệ.", nil, "Văn phòng dịch vụ giả lập tại TP.HCM"],
  "Equipment maintenance – demo" => ["2026-10-26", 550_000, "Demo: thay quạt tản nhiệt và vệ sinh máy tính văn phòng.", "11:15", "Điểm sửa máy tính mẫu tại Nha Trang"],

  "Sample: Retail orders · May" => ["2026-05-06", 4_200_000, "Demo: thu tiền từ 6 đơn hàng phụ kiện, sổ tay và đồ dùng học tập.", "14:10", "Quầy bán hàng mẫu tại Nha Trang"],
  "Sample: Office materials · May" => ["2026-05-13", 610_000, "Demo: mua giấy in A4, bút dạ và tài liệu đóng gáy.", "08:35", "Cửa hàng văn phòng phẩm giả lập tại Nha Trang"],
  "Sample: Delivery transport · May" => ["2026-05-19", 385_000, "Demo: trả phí giao 4 kiện hàng tới khách.", nil, nil],
  "Sample: Consulting invoice · May" => ["2026-05-25", 1_750_000, "Demo: khách trả phí tư vấn tối ưu website.", "15:25", "Phòng họp trực tuyến (dữ liệu mẫu)"],

  "Sample: Retail orders · June" => ["2026-06-04", 5_100_000, "Demo: thu tiền 8 đơn hàng vật tư văn phòng và phụ kiện.", "10:55", "Quầy bán hàng mẫu tại Đà Nẵng"],
  "Sample: Equipment maintenance · June" => ["2026-06-12", 720_000, "Demo: thay ổ cắm điện, dây nguồn và bảo dưỡng máy in.", "13:20", "Đơn vị bảo trì giả lập tại Nha Trang"],
  "Sample: Consulting invoice · June" => ["2026-06-20", 2_150_000, "Demo: thanh toán dịch vụ tư vấn cấu trúc dữ liệu.", nil, nil],
  "Sample: Office materials · June" => ["2026-06-25", 975_000, "Demo: mua giấy in, hộp mực và hồ sơ lưu trữ.", "09:40", "Cửa hàng thiết bị văn phòng mẫu tại TP.HCM"],

  "Sample: Retail orders · July" => ["2026-07-05", 5_700_000, "Demo: doanh thu 9 đơn hàng đồ dùng gia đình và học tập.", "17:05", "Cửa hàng bán lẻ mẫu tại Đà Nẵng"],
  "Sample: Delivery transport · July" => ["2026-07-13", 460_000, "Demo: thanh toán vận chuyển các thùng hàng giao nội thành.", "08:50", nil],
  "Sample: Consulting invoice · July" => ["2026-07-21", 2_300_000, "Demo: khách trả phí tư vấn triển khai ứng dụng Rails.", "11:10", "Họp trực tuyến (dữ liệu mẫu)"],
  "Sample: Equipment maintenance · July" => ["2026-07-26", 840_000, "Demo: vệ sinh máy lạnh và kiểm tra điện văn phòng.", nil, "Cơ sở bảo dưỡng giả lập tại Nha Trang"],

  "Sample: Retail orders · August" => ["2026-08-06", 6_950_000, "Demo: thu tiền các đơn hàng phụ kiện máy tính và văn phòng phẩm.", "16:15", "Quầy bán hàng mẫu tại Đà Nẵng"],
  "Sample: Office materials · August" => ["2026-08-14", 1_210_000, "Demo: mua giấy A4, mực in và thùng đựng tài liệu.", "10:30", "Cửa hàng văn phòng phẩm giả lập tại Đà Nẵng"],
  "Sample: Consulting invoice · August" => ["2026-08-22", 2_640_000, "Demo: khách thanh toán dịch vụ tối ưu hiệu năng hệ thống.", nil, nil],
  "Sample: Delivery transport · August" => ["2026-08-27", 590_000, "Demo: trả phí giao hàng và vận chuyển thùng carton.", "17:45", "Điểm gửi hàng giả lập tại Nha Trang"],

  "Sample: Retail orders · September" => ["2026-09-05", 7_600_000, "Demo: doanh thu 12 đơn hàng đồ gia dụng và phụ kiện.", "15:50", "Cửa hàng bán lẻ mẫu tại Nha Trang"],
  "Sample: Equipment maintenance · September" => ["2026-09-11", 965_000, "Demo: thay linh kiện và vệ sinh máy in cùng máy tính.", nil, "Trung tâm sửa chữa giả lập tại Đà Nẵng"],
  "Sample: Consulting invoice · September" => ["2026-09-20", 2_920_000, "Demo: khách trả phí tư vấn hệ thống bán hàng và báo cáo.", "14:30", "Văn phòng giả lập tại TP.HCM"],
  "Sample: Office materials · September" => ["2026-09-26", 1_170_000, "Demo: mua 5 ram giấy A4, bút bi, bìa hồ sơ và vật tư đóng gói cho văn phòng.", "09:25", "Cửa hàng văn phòng phẩm giả lập gần trung tâm Đà Nẵng"],

  "Sample: Retail orders · October" => ["2026-10-06", 4_400_000, "Demo: thu tiền bán phụ kiện máy tính, sổ tay và vật dụng văn phòng.", "15:05", "Quầy bán hàng giả lập tại Nha Trang"],
  "Sample: Promotional supplies · October" => ["2026-10-13", 1_290_000, "Demo: mua poster, tờ rơi và túi đóng gói cho chương trình khuyến mãi.", "11:55", "Xưởng in mẫu tại Đà Nẵng"],
  "Sample: Courier delivery · October" => ["2026-10-23", 350_000, "Demo: trả phí chuyển phát 5 kiện hàng cho khách.", "14:35", "Bưu cục giả lập tại Đà Nẵng"]
}.freeze

raise "Expected 28 established demo transactions" unless samples.size == 28

created = 0
existing = 0
samples.each do |description, (day, amount, details, time, place)|
  rows = Finance::Transaction.for_workspace(workspace.id)
    .where(description: description, transaction_date: Date.iso8601(day))
  raise "Missing or duplicate demo transaction: #{description}" unless rows.count == 1
  transaction = rows.first
  unless transaction.confirmed? && transaction.amount == BigDecimal(amount)
    raise "Ledger identity mismatch: #{description}"
  end

  if transaction.context
    ctx = transaction.context
    unless ctx.source == "demo_seed" && ctx.purchase_details == details &&
           ctx.occurred_time&.strftime("%H:%M") == time && ctx.location_text == place
      raise "Existing contextual evidence differs; refusing overwrite: #{description}"
    end
    existing += 1
    next
  end

  Finance::Transaction.transaction do
    ctx = transaction.create_context!(
      recorded_by: user, source: "demo_seed",
      purchase_details: details, occurred_time: time, location_text: place
    )
    Finance::AuditEvent.create!(
      finance_transaction: transaction, workspace_id: workspace.id,
      actor_id: user.id, event_type: "synthetic_demo_context_added",
      payload: { context_id: ctx.id, source: "demo_seed", financial_values_unchanged: true }
    )
  end
  created += 1
end

# Reproduce the user's illustrative bakery scenario as a separately confirmed demo entry.
bakery_description = "Demo: Mua bánh mì ngọt cho bữa sáng"
bakery = Finance::Transaction.for_workspace(workspace.id).find_by(description: bakery_description)
if bakery
  expected = bakery.transaction_date == Date.new(2026, 4, 26) &&
    bakery.amount == BigDecimal("30000") && bakery.kind == "expense" &&
    bakery.context&.source == "demo_seed" &&
    bakery.context&.occurred_time&.strftime("%H:%M") == "08:12"
  raise "Bakery seed mismatch; will not overwrite" unless expected
else
  Finance::Transaction.transaction do
    bakery = workspace.finance_transactions.create!(
      kind: "expense", status: "draft", entry_source: "manual",
      currency_code: "VND", created_by_id: user.id,
      transaction_date: Date.new(2026, 4, 26), amount: BigDecimal("30000"),
      description: bakery_description
    )
    bakery.line_items.create!(
      position: 0, description: "Bánh mì ngọt (ví dụ giả lập)",
      amount: BigDecimal("30000"), entry_source: "manual"
    )
    bakery.create_context!(
      recorded_by: user, source: "demo_seed",
      purchase_details: "Mua bánh mì ngọt ăn sáng; ví dụ giao dịch do người dùng đề xuất.",
      occurred_time: "08:12",
      location_text: "Địa điểm giả lập: tiệm bánh gần đồn cảnh sát tại Đà Nẵng"
    )
    Finance::ConfirmTransaction.call(transaction: bakery, actor: user, reviewed: true)
  end
end

record26 = Finance::Transaction.for_workspace(workspace.id).find_by(id: 26)
if record26 && record26.description == "Sample: Office materials · September"
  raise "Transaction #26 metadata missing" unless
    record26.context&.purchase_details&.include?("giấy A4") &&
    record26.context&.occurred_time&.strftime("%H:%M") == "09:25"
end

puts "DEMO_CONTEXT_PASS created=#{created} previously_present=#{existing} "     "existing_contexts=#{Finance::TransactionContext.joins(:finance_transaction).where(finance_transactions: { workspace_id: workspace.id }).count} "     "bakery_id=#{bakery.id} confirmed_total=#{Finance::Transaction.for_workspace(workspace.id).confirmed.count}"
