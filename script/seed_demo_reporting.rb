# frozen_string_literal: true

# Opt-in, synthetic-only reporting samples. Never invoked by db/seeds.rb.
# Run only on the temporary private demo workspace:
# FINANCE_DEMO_PREVIEW=1 bin/rails runner script/seed_demo_reporting.rb
raise "Explicit demo flag required" unless ENV["FINANCE_DEMO_PREVIEW"] == "1"
raise "Demo samples are forbidden outside development" unless Rails.env.development?

user = User.find_by(email_address: "finance.demo@example.test")
raise "Existing demo user required; no account is created" unless user

workspace = user.workspaces.find_by(name: "Finance Demo Workspace")
raise "Expected private demo workspace not found" unless workspace

# All entries are made up. None represents a receipt or a real-world payment.
samples = [
  ["2026-05-06", "income",  "4200000", "sales",       "Sample: Retail orders · May"],
  ["2026-05-13", "expense", "610000",  "office",      "Sample: Office materials · May"],
  ["2026-05-19", "expense", "385000",  "transport",   "Sample: Delivery transport · May"],
  ["2026-05-25", "income",  "1750000", "services",    "Sample: Consulting invoice · May"],

  ["2026-06-04", "income",  "5100000", "sales",       "Sample: Retail orders · June"],
  ["2026-06-12", "expense", "720000",  "maintenance", "Sample: Equipment maintenance · June"],
  ["2026-06-20", "income",  "2150000", "services",    "Sample: Consulting invoice · June"],
  ["2026-06-25", "expense", "975000",  "office",      "Sample: Office materials · June"],

  ["2026-07-05", "income",  "5700000", "sales",       "Sample: Retail orders · July"],
  ["2026-07-13", "expense", "460000",  "transport",   "Sample: Delivery transport · July"],
  ["2026-07-21", "income",  "2300000", "services",    "Sample: Consulting invoice · July"],
  ["2026-07-26", "expense", "840000",  "maintenance", "Sample: Equipment maintenance · July"],

  ["2026-08-06", "income",  "6950000", "sales",       "Sample: Retail orders · August"],
  ["2026-08-14", "expense", "1210000", "office",      "Sample: Office materials · August"],
  ["2026-08-22", "income",  "2640000", "services",    "Sample: Consulting invoice · August"],
  ["2026-08-27", "expense", "590000",  "transport",   "Sample: Delivery transport · August"],

  ["2026-09-05", "income",  "7600000", "sales",       "Sample: Retail orders · September"],
  ["2026-09-11", "expense", "965000",  "maintenance", "Sample: Equipment maintenance · September"],
  ["2026-09-20", "income",  "2920000", "services",    "Sample: Consulting invoice · September"],
  ["2026-09-26", "expense", "1170000", "office",      "Sample: Office materials · September"],

  ["2026-10-06", "income",  "4400000", "sales",       "Sample: Retail orders · October"],
  ["2026-10-13", "expense", "1290000", "office",      "Sample: Promotional supplies · October"],
  ["2026-10-23", "expense", "350000",  "transport",   "Sample: Courier delivery · October"]
].freeze

added = 0
skipped = 0
samples.each do |date, kind, amount, category, description|
  day = Date.iso8601(date)
  existing = Finance::Transaction.for_workspace(workspace.id).find_by(
    kind: kind, transaction_date: day, description: description
  )
  if existing
    raise "Conflicting existing sample: #{description}" unless
      existing.confirmed? && existing.amount == BigDecimal(amount) && existing.category == category
    skipped += 1
    next
  end

  tx = Finance::Transaction.create!(
    workspace_id: workspace.id, created_by_id: user.id, status: "draft",
    entry_source: "manual", currency_code: "VND", kind: kind,
    amount: BigDecimal(amount), category: category, description: description,
    transaction_date: day
  )
  Finance::ConfirmTransaction.call(transaction: tx, actor: user, reviewed: true)
  added += 1
end

confirmed = Finance::Transaction.for_workspace(workspace.id).confirmed.count
puts "SYNTHETIC_DEMO_SAMPLES_PASS added=#{added} skipped=#{skipped} confirmed_total=#{confirmed}"
