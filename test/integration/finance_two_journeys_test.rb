require "test_helper"

class FinanceTwoJourneysTest < ActionDispatch::IntegrationTest
  setup do
    @user = User.create!(email_address: "two-journeys@example.test", password: "SecureDemo-2026!")
    @workspace = @user.workspaces.create!(name: "Two Journeys")
    post session_path, params: {email_address: @user.email_address, password: "SecureDemo-2026!"}
    assert_response :redirect
  end

  test "expense intake shows image-first mode with compact manual fallback" do
    get new_finance_transaction_path(kind: "expense", locale: "vi")
    assert_response :success
    assert_select "nav.finance-mode-switch a.finance-mode-link.is-active[href*='kind=expense']", count: 1
    assert_select "h1", text: "Ghi nhận khoản chi"
    assert_select "form[action='#{from_receipt_finance_transactions_path}'] input[name='receipt[kind]'][value='expense']"
    assert_select "form[action='#{from_receipt_finance_transactions_path}'] input[name='receipt[image]']"
    assert_select "details.intake-manual", count: 1
    assert_select "details.intake-manual[open]", count: 0
    assert_select "form[action='#{finance_transactions_path}'] input[name='finance_transaction[kind]'][value='expense']"
    assert_select "form[action='#{finance_transactions_path}'] input[name='finance_transaction[amount]']"
    assert_select "form[action='#{finance_transactions_path}'] details.entry-optional-fields select[name='finance_transaction[category]']"
    assert_select "input[name='finance_transaction[context_attributes][location_text]']", count: 0
  end

  test "income intake prioritizes amount source date, optional category and proof, no expense upload-first" do
    get new_finance_transaction_path(kind: "income", locale: "vi")
    assert_response :success
    assert_select "h1", text: "Ghi nhận khoản thu"
    assert_select "nav.finance-mode-switch a.finance-mode-link.is-active[href*='kind=income']", count: 1
    assert_select "form[action='#{finance_transactions_path}'] input[name='finance_transaction[kind]'][value='income']"
    assert_select "form[action='#{finance_transactions_path}'] input[name='entry_mode'][value='quick_income']"
    assert_select "form[action='#{finance_transactions_path}'] input[name='finance_transaction[amount]'][required]"
    assert_select "form[action='#{finance_transactions_path}'] input[name='finance_transaction[description]'][required]"
    assert_select "form[action='#{finance_transactions_path}'] input[name='finance_transaction[transaction_date]'][required]"
    assert_select "details.income-evidence-panel[open]", count: 1
    assert_select "details.income-evidence-panel form[action='#{from_receipt_finance_transactions_path}'] input[name='receipt[kind]'][value='income']"
    assert_select "details.income-evidence-panel label[for='receipt_image']", count: 1
    assert_select "details.entry-optional-fields select[name='finance_transaction[category]']"
    assert_select "details.intake-manual", count: 0
    assert_select "form[data-controller='receipt-upload']", count: 1
    assert_includes response.body, "Bộ đọc ảnh GGUF chưa kết nối"

    get new_finance_transaction_path(kind: "income", locale: "en")
    assert_response :success
    assert_select "h1", text: "Record income"
    assert_select "nav.finance-mode-switch a.finance-mode-link.is-active[href*='kind=income']", count: 1
    assert_includes response.body, "Amount received"
    assert_includes response.body, "Received from / reason"
  end

  test "valid income quick entry creates unconfirmed draft and redirects to income-specific review" do
    assert_difference "Finance::Transaction.count", 1 do
      post finance_transactions_path, params: {
        entry_mode: "quick_income",
        finance_transaction: {
          kind: "income", amount: "87000", description: "Client payment",
          transaction_date: "2026-10-30"
        }
      }
      assert_response :redirect
    end
    tx = @workspace.finance_transactions.order(:id).last
    assert_redirected_to review_finance_transaction_path(tx)
    assert tx.draft?
    assert_equal "income", tx.kind
    assert_equal BigDecimal("87000"), tx.amount
    assert_nil tx.category
    assert_equal "manual", tx.entry_source
    assert_equal 0, tx.field_suggestions.count
    get review_finance_transaction_path(tx,locale:"en")
    assert_response :success
    assert_select "h1", text: /Review income/
    assert_select ".income-review-layout", count: 1
    assert_select ".income-amount-control", count: 1
    assert_select "details.income-evidence-panel", minimum: 1
    assert_select "form[action='#{finance_transaction_path(tx)}'] input[name='finance_transaction[amount]']"
    assert_select "form[action='#{finance_transaction_path(tx)}'] input[name='return_to_review'][value='1']"
    assert_select "form[action='#{finance_transaction_document_versions_path(tx)}'] input[name='document_version[image]']"
    assert_select ".income-review-layout img.receipt-review-image", count: 0
    assert_select "a[href='#{finance_transaction_line_items_path(tx)}']", minimum: 1
    assert_select "form[action='#{confirm_finance_transaction_path(tx)}']", count: 0
    post confirm_finance_transaction_path(tx),params:{human_confirmed:"0"}
    assert tx.reload.draft?
  end

  test "income quick entry refuses missing critical fields without creating a draft" do
    [{amount:nil,transaction_date:"2026-10-30",description:"Consulting"},
      {amount:"-1",transaction_date:"2026-10-30",description:"Consulting"},
      {amount:"100",transaction_date:nil,description:"Consulting"},
      {amount:"100",transaction_date:"2026-10-30",description:""}].each do |data|
      assert_no_difference "Finance::Transaction.count" do
        post finance_transactions_path,params:{entry_mode:"quick_income",
          finance_transaction: {kind:"income"}.merge(data)}
        assert_response :unprocessable_entity
        assert_select "h1", text: "Record income"
        assert_select "details.income-evidence-panel[open]", count: 1
      end
    end
  end

  test "income document can be added after quick entry and returns to income review" do
    post finance_transactions_path, params:{entry_mode:"quick_income",
      finance_transaction:{kind:"income",amount:"50000",description:"Service fee",
                           transaction_date:"2026-10-29"}}
    tx = @workspace.finance_transactions.order(:id).last
    assert_nil tx.active_document_version
    assert_difference "Finance::DocumentVersion.count", 1 do
      post finance_transaction_document_versions_path(tx),
        params:{return_to_review:"1",document_version:{image:sample_image}}
      assert_response :redirect
    end
    assert_redirected_to review_finance_transaction_path(tx)
    tx.reload
    assert tx.active_document_version&.image&.attached?
    assert_equal 64,tx.active_document_version.sha256.length
    get review_finance_transaction_path(tx,locale:"vi")
    assert_response :success
    assert_select "img.receipt-review-image", count: 1
    assert_select "h1", text: /Kiểm tra khoản thu/
    assert_includes response.body, "Bộ đọc ảnh GGUF chưa kết nối"
    assert_equal BigDecimal("50000"),tx.amount
    assert tx.draft?
  end

  test "income uploaded proof creates empty income draft without fake amount or AI inference" do
    assert_difference "Finance::Transaction.count", 1 do
      post from_receipt_finance_transactions_path,
        params:{receipt:{kind:"income",image:sample_image}}
      assert_response :redirect
    end
    tx = @workspace.finance_transactions.order(:id).last
    assert_equal "income",tx.kind
    assert_nil tx.amount
    assert_nil tx.transaction_date
    assert_nil tx.description
    assert_equal 0, tx.field_suggestions.count
    assert_redirected_to review_finance_transaction_path(tx)
    get review_finance_transaction_path(tx,locale:"en")
    assert_response :success
    assert_select "h1", text: /Review income/
    assert_select "img.receipt-review-image", count: 1
  end

  private

  def sample_image
    Rack::Test::UploadedFile.new(Rails.root.join("test/fixtures/files/receipt_sample.png"),"image/png")
  end
end
