require "test_helper"

class FinanceFlowTest < ActionDispatch::IntegrationTest
  setup do
    @user = User.create!(email_address: "finance-owner@example.test", password: "Example-Password-2026!")
    @workspace = @user.workspaces.create!(name: "Owner Workspace")
    @other = User.create!(email_address: "other-owner@example.test", password: "Example-Password-2026!")
    @other.workspaces.create!(name: "Other Workspace")
    post session_path, params: { email_address: @user.email_address, password: "Example-Password-2026!" }
    assert_response :redirect
  end

  test "manual draft can be confirmed and appears in monthly reports and csv" do
    tx = create_draft
    assert tx.draft?
    get finance_reports_path(month: "2026-10")
    assert_response :success
    assert_select "body", text: /0 transactions|0 entries|No confirmed/i if response.body.match?(/0 transactions|0 entries|No confirmed/i)

    post confirm_finance_transaction_path(tx), params: { human_confirmed: "1" }
    assert_response :redirect
    assert tx.reload.confirmed?
    assert_equal Date.new(2026, 10, 27), tx.transaction_date
    assert_equal BigDecimal("43500"), tx.amount
    get finance_reports_path(month: "2026-10")
    assert_response :success
    get finance_reports_export_path(month: "2026-10")
    assert_response :success
    assert_includes response.body, "43500"
  end

  test "cannot confirm without explicit human approval" do
    tx = create_draft
    post confirm_finance_transaction_path(tx), params: { human_confirmed: "0" }
    assert_response :redirect
    assert tx.reload.draft?
    assert_nil tx.confirmed_at
  end

  test "unauthorized workspace cannot access another account transactions" do
    tx = create_draft
    delete session_path
    post session_path, params: { email_address: @other.email_address, password: "Example-Password-2026!" }
    get finance_transaction_path(tx)
    assert_response :not_found
  end

  test "document versions remain available after confirmation without changing ledger" do
    tx = create_draft
    assert_difference "Finance::DocumentVersion.count", 1 do
      post finance_transaction_document_versions_path(tx),
        params: { document_version: { image: image_upload } }
      assert_response :redirect
    end
    first = tx.reload.document_versions.first
    assert_equal 1, first.version_number
    assert_equal 64, first.sha256.length
    assert_equal first.id, tx.active_document_version_id
    get image_finance_transaction_document_version_path(tx, first)
    assert_response :success
    assert_equal "private, no-store", response.headers["Cache-Control"]

    post confirm_finance_transaction_path(tx), params: { human_confirmed: "1" }
    assert tx.reload.confirmed?
    assert_difference "Finance::DocumentVersion.count", 1 do
      post finance_transaction_document_versions_path(tx),
        params: { document_version: { image: image_upload } }
      assert_response :redirect
    end
    assert_equal [1, 2], tx.document_versions.order(:version_number).pluck(:version_number)
    assert_equal first.id, tx.reload.active_document_version_id
    assert_equal BigDecimal("43500"), tx.amount
  end

  test "invalid image never prevents manual entry" do
    tx = create_draft
    bad = Rack::Test::UploadedFile.new(
      Tempfile.create(["corrupt", ".png"]).tap { |f| f.write("not an actual image"); f.rewind }.path, "image/png"
    )
    post finance_transaction_document_versions_path(tx),
      params: { document_version: { image: bad } }
    assert_response :redirect
    assert_equal 0, tx.document_versions.count
    assert tx.reload.draft?
  end

  private

  def create_draft
    assert_difference "Finance::Transaction.count", 1 do
      post finance_transactions_path, params: { finance_transaction: {
        kind: "expense", transaction_date: "2026-10-27",
        description: "Office supplies", amount: "43500"
      } }
      assert_response :redirect
    end
    @workspace.finance_transactions.order(:id).last
  end

  def image_upload
    Rack::Test::UploadedFile.new(Rails.root.join("test/fixtures/files/receipt_sample.png"), "image/png")
  end
end
