require "test_helper"

class FinanceReceiptIntakeTest < ActionDispatch::IntegrationTest
  setup do
    @user = User.create!(email_address: "intake-owner@example.test", password: "SecureExample-2026!")
    @workspace = @user.workspaces.create!(name: "Receipt-first Workspace")
    @other = User.create!(email_address: "intake-other@example.test", password: "SecureExample-2026!")
    @other.workspaces.create!(name: "Unrelated Workspace")
    post session_path, params: {email_address: @user.email_address, password: "SecureExample-2026!"}
    assert_response :redirect
  end

  test "new transaction prioritizes photo and keeps manual form collapsed in both languages" do
    get new_finance_transaction_path(locale: "vi")
    assert_response :success
    assert_select "h1", text: /Tạo giao dịch thu hoặc chi/
    assert_select "form[action='#{from_receipt_finance_transactions_path}'][enctype='multipart/form-data']", count: 1
    assert_select "input[type='file'][name='receipt[image]'][required]", count: 1
    assert_select "form[data-controller='receipt-upload']", count: 1
    assert_select "details.intake-manual", count: 1
    assert_select "details.intake-manual[open]", count: 0
    assert_select "input[name='finance_transaction[amount]']", count: 1
    assert_select "input[name='finance_transaction[transaction_date]']", count: 1
    assert_includes response.body, "Chưa kết nối" if response.body.include?("Chưa kết nối")
    get new_finance_transaction_path(locale: "en")
    assert_response :success
    assert_select "h2", text: /Upload income or expense evidence/
    assert_select "details.intake-manual", count: 1
    assert_includes response.body, "GGUF adapter"
  end

  test "receipt upload creates an empty draft with immutable image and audit, without fake AI values" do
    assert_difference "Finance::Transaction.count", 1 do
      assert_difference "Finance::DocumentVersion.count", 1 do
        post from_receipt_finance_transactions_path, params: {
          receipt: {kind: "expense", image: sample_image}
        }
        assert_response :redirect
      end
    end
    tx = @workspace.finance_transactions.order(:id).last
    assert_redirected_to review_finance_transaction_path(tx)
    assert tx.draft?
    assert_equal "manual", tx.entry_source
    assert_nil tx.amount
    assert_nil tx.transaction_date
    assert_nil tx.description
    assert_nil tx.tags.first&.key
    assert_equal 0, tx.line_items.count
    assert_equal 0, tx.field_suggestions.count
    assert_equal 0, Finance::ExtractionRun.count
    assert tx.active_document_version.image.attached?
    assert_equal 64, tx.active_document_version.sha256.length
    assert_equal "receipt_first_draft_created", tx.audit_events.order(:id).last.event_type
    assert_equal false, tx.audit_events.order(:id).last.payload.fetch("ai_inference_invoked")
    assert_equal true, tx.audit_events.order(:id).last.payload.fetch("human_review_required")

    get review_finance_transaction_path(tx, locale: "vi")
    assert_response :success
    assert_select "h1", text: /Kiểm tra hóa đơn/
    assert_select "img.receipt-review-image", count: 1
    assert_select "input[name='finance_transaction[amount]']", count: 0
    assert_select ".locked-transaction-total", count: 1
    assert_includes response.body, "Chưa kết nối AI"
    assert_select "a[href='#{finance_transaction_line_items_path(tx)}']", minimum: 1
    assert_select "form[action='#{finance_transaction_path(tx)}']", count: 1
    assert_select "input[name='return_to_review'][value='1']", count: 1
    assert_select "form[action='#{confirm_finance_transaction_path(tx)}']", count: 0

    get finance_transaction_path(tx)
    assert_response :success
    assert_select "a[href='#{review_finance_transaction_path(tx)}']", count: 1
  end

  test "reviewed edits persist in draft; missing fields remain unknown and cannot auto-confirm" do
    tx = upload_draft
    post finance_transaction_line_items_path(tx), params: {line_item: {
      description: "Sweet bread", amount: "30000"
    }}
    assert_response :redirect
    patch finance_transaction_path(tx), params: {
      return_to_review: "1",
      revision_reason: "Verified these draft fields against the saved image.",
      finance_transaction: {
        transaction_date: "2026-04-26", amount: "30000",
        description: "Sweet bread",
        context_attributes: {purchase_details: "Breakfast", occurred_time: "08:12"}
      }
    }
    assert_redirected_to review_finance_transaction_path(tx)
    assert_equal Date.new(2026,4,26), tx.reload.transaction_date
    assert_equal BigDecimal("30000"), tx.amount
    assert_equal "Sweet bread", tx.description
    assert_equal "08:12", tx.context.occurred_time.strftime("%H:%M")
    assert_nil tx.context.location_text
    assert tx.draft?

    post confirm_finance_transaction_path(tx), params: {human_confirmed: "0"}
    assert_response :redirect
    assert tx.reload.draft?
  end

  test "bad image does not leave draft or orphan evidence; manual route remains available" do
    bad_file = Tempfile.create(["not-image", ".png"])
    bad_file.write("This is not an image")
    bad_file.flush
    bad = Rack::Test::UploadedFile.new(bad_file.path, "image/png")
    before = [Finance::Transaction.count, Finance::DocumentVersion.count, Finance::AuditEvent.count]
    post from_receipt_finance_transactions_path, params: {receipt: {kind:"expense", image: bad}}
    assert_response :redirect
    assert_redirected_to new_finance_transaction_path(kind:"expense")
    assert_equal before, [Finance::Transaction.count, Finance::DocumentVersion.count, Finance::AuditEvent.count]

    post finance_transactions_path, params: {finance_transaction: {
      kind: "expense", transaction_date: "2026-10-30",
      amount: "2000", description: "No receipt"
    }}
    assert_response :redirect
    assert_equal "No receipt", @workspace.finance_transactions.order(:id).last.description
  ensure
    bad_file&.close; File.unlink(bad_file.path) if bad_file && File.exist?(bad_file.path)
  end

  test "intake and review remain workspace scoped" do
    tx = upload_draft
    delete session_path
    post session_path, params: {email_address: @other.email_address, password: "SecureExample-2026!"}
    get review_finance_transaction_path(tx)
    assert_response :not_found
    patch finance_transaction_path(tx), params: {return_to_review: "1",
      finance_transaction: {description: "Unauthorized"}}
    assert_response :not_found
    assert_nil tx.reload.description
  end

  private

  def sample_image
    Rack::Test::UploadedFile.new(Rails.root.join("test/fixtures/files/receipt_sample.png"), "image/png")
  end

  def upload_draft
    post from_receipt_finance_transactions_path, params: {receipt: {kind:"expense",image:sample_image}}
    assert_response :redirect
    @workspace.finance_transactions.order(:id).last
  end
end
