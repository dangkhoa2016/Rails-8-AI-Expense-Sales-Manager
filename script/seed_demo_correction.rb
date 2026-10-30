# frozen_string_literal: true
# Opt-in synthetic correction demonstration. No original confirmed rows are mutated.
raise "Development demo only" unless Rails.env.development? && ENV["FINANCE_DEMO_PREVIEW"] == "1"
user = User.find_by(email_address: "finance.demo@example.test")
workspace = user&.workspaces&.find_by(name: "Finance Demo Workspace")
raise "Dedicated demo account missing" unless workspace

source = Finance::Transaction.for_workspace(workspace.id)
  .find_by!(description: "Demo: Itemized receipt with 100 items")
raise "Original demo transaction is not approved" unless source.confirmed?
raise "Expected 100 demo lines" unless source.line_items.count == 100
raise "Amount missing" unless source.amount && source.amount.positive?

already = source.correction_as_original
if already
  raise "Existing correction not yet confirmed" unless already.confirmed?
  puts "CORRECTION_DEMO_ALREADY_SEEDED source=#{source.id} replacement=#{already.replacement_transaction_id}"
else
  correction = Finance::BeginCorrection.call(
    original: source, actor: user,
    reason: "Synthetic demo correction: adjust the first purchased item by 5,000 VND."
  )
  replacement = correction.replacement_transaction
  item = replacement.line_items.order(:position).first
  item.update!(amount: item.amount + BigDecimal("5000"))
  replacement.update!(
    amount: source.amount + BigDecimal("5000"),
    description: "Demo: Corrected 100-item receipt (+5,000 VND)"
  )
  Finance::ConfirmCorrection.call(correction: correction, actor: user, reviewed: true)
  raise "Original values changed" unless source.reload.amount == replacement.amount - 5000
  puts "CORRECTION_DEMO_PASS source=#{source.id} replacement=#{replacement.id} "       "source_amount=#{source.amount.to_s('F')} effective_amount=#{replacement.amount.to_s('F')} "       "original_items=#{source.line_items.count} copied_items=#{replacement.line_items.count}"
end
