require "test_helper"
require "csv"
require "stringio"

class FinanceBulkLineItemsTest < ActionDispatch::IntegrationTest
  setup do
    @user = User.create!(email_address: "items-owner@example.test", password: "ExamplePass-2026!")
    @workspace = @user.workspaces.create!(name: "Itemized Workspace")
    @other = User.create!(email_address: "items-other@example.test", password: "ExamplePass-2026!")
    @other.workspaces.create!(name: "Other Workspace")
    post session_path, params: { email_address: @user.email_address, password: "ExamplePass-2026!" }
    assert_response :redirect
    @transaction = @workspace.finance_transactions.create!(
      kind: "expense", status: "draft", created_by_id: @user.id,
      currency_code: "VND", entry_source: "manual", description: "100-row sample receipt",
      amount: BigDecimal("2000000"), transaction_date: Date.new(2026, 10, 20)
    )
  end

  test "100 CSV items inherit transaction date and synchronize amount without replay" do
    csv = sample_csv(100)
    assert_difference "Finance::LineItem.count", 100 do
      post import_finance_transaction_line_items_path(@transaction), params: {file: upload(csv)}
      assert_response :redirect
    end
    assert_equal 100, @transaction.line_items.count
    assert_equal 1, @transaction.line_import_batches.count
    assert_equal BigDecimal("100000"), @transaction.reload.amount
    assert_equal 100, Finance::AuditEvent.where(transaction_id: @transaction.id, event_type: "finance_line_items_csv_imported").first.payload["row_count"]

    assert_no_difference "Finance::LineItem.count" do
      post import_finance_transaction_line_items_path(@transaction), params: {file: upload(csv)}
      assert_response :redirect
    end
    assert_equal 1, @transaction.line_import_batches.count

    get finance_transaction_line_items_path(@transaction)
    assert_response :success
    assert_select "tbody tr", count: 25
    get finance_transaction_line_items_path(@transaction, page: 4)
    assert_response :success
    assert_select "tbody tr", count: 25
    get finance_transaction_path(@transaction)
    assert_response :success
    assert_select ".recent-entry", count: 5
    assert_includes response.body, "100"

    get finance_reports_path(month: "2026-10")
    assert_response :success
    refute_includes response.body, "2,000,000"
    post confirm_finance_transaction_path(@transaction), params: {human_confirmed: "1"}
    assert_response :redirect
    assert @transaction.reload.confirmed?
    get finance_reports_path(month: "2026-10")
    assert_response :success
    assert_includes response.body, "100,000"
    get finance_transaction_line_items_path(@transaction)
    assert_response :success
    assert_select "tbody tr", count: 25
    assert_select 'form[action*="/import"]', count: 0

    assert_no_difference "Finance::LineItem.count" do
      post import_finance_transaction_line_items_path(@transaction), params: {file: upload(sample_csv(1))}
      assert_response :not_found
    end
  end

  test "bad row rolls back everything, including import batch and audit" do
    bad = "description,amount,quantity,unit_price,tags\nGood,12000,1,12000,food\nBad,12.456,1,10,food\n"
    assert_no_difference "Finance::LineItem.count" do
      assert_no_difference "Finance::LineImportBatch.count" do
        post import_finance_transaction_line_items_path(@transaction), params: {file: upload(bad)}
        assert_response :redirect
      end
    end
    assert_equal 0, @transaction.line_items.count
    assert_equal 0, Finance::AuditEvent.where(transaction_id: @transaction.id, event_type: "finance_line_items_csv_imported").count

    assert_no_difference "Finance::LineItem.count" do
      post import_finance_transaction_line_items_path(@transaction), params: {file: upload(sample_csv(501))}
      assert_response :redirect
    end
    assert_equal 0, @transaction.line_import_batches.count
  end

  test "manual item CRUD synchronizes draft parent and preserves empty manual total" do
    post finance_transaction_line_items_path(@transaction), params: {line_item: {
      description: "Bánh mì ngọt", amount: "30000", quantity: "2", unit_price: "15000",
      position: "9999", tag_selection: "1", new_tags: "food"
    }}
    assert_response :redirect
    item = @transaction.line_items.sole
    assert_equal 0, item.position
    assert_equal BigDecimal("2"), item.quantity
    assert_equal BigDecimal("15000"), item.unit_price
    assert_equal "food", item.tags.first&.key
    patch finance_transaction_line_item_path(@transaction, item), params: {line_item: {
      description: "Bánh mì", amount: "30000"
    }}
    assert_response :redirect
    assert_equal "Bánh mì", item.reload.description
    assert_equal BigDecimal("30000"), @transaction.reload.amount
    delete finance_transaction_line_item_path(@transaction, item)
    assert_response :redirect
    assert_equal 0, @transaction.line_items.count
  end

  test "nested draft uses parent date even if old clients submit item dates" do
    entries = 75.times.each_with_object({}) do |i, hash|
      hash[i.to_s] = {position: i, description: "Item #{i+1}", amount: "500", occurred_on: "2026-10-20"}
    end
    assert_difference "Finance::LineItem.count", 75 do
      post finance_transactions_path, params: {finance_transaction: {
        kind: "expense", transaction_date: "2026-10-20", amount: "99999",
        description: "75-line nested draft", line_items_attributes: entries
      }}
      assert_response :redirect
    end
    tx = @workspace.finance_transactions.order(:id).last
    assert tx.draft?
    assert_equal BigDecimal("37500"), tx.amount
    assert_equal 75, tx.line_items.count
    assert tx.line_items.all? { |line| line.occurred_on.nil? && line.effective_date == tx.transaction_date }
  end

  test "another workspace cannot fetch or import item data" do
    tx = @transaction
    delete session_path
    post session_path, params: {email_address: @other.email_address, password: "ExamplePass-2026!"}
    get finance_transaction_line_items_path(tx)
    assert_response :not_found
    get finance_transaction_line_items_path(tx, name: "Sample", time_from: "09:00",
      amount_min: "1")
    assert_response :not_found
    assert_no_difference "Finance::LineItem.count" do
      post import_finance_transaction_line_items_path(tx), params: {file: upload(sample_csv(10))}
      assert_response :not_found
    end
  end

  test "100 AI extraction proposals are paginated and reviewing one never posts money" do
    receipt = Rack::Test::UploadedFile.new(
      Rails.root.join("test/fixtures/files/receipt_sample.png"), "image/png"
    )
    post finance_transaction_document_versions_path(@transaction),
      params: {document_version: {image: receipt}}
    assert_response :redirect
    version = @transaction.reload.active_document_version
    assert version

    output = {
      "readability_status" => "readable",
      "line_items" => 100.times.map do |i|
        {"label" => "Proposed item #{i + 1}", "amount_literal" => "1000",
         "amount_vnd" => "1000"}
      end
    }
    Finance::RecordExtraction.call(
      document_version: version, model_sha256: "a" * 64,
      prompt_sha256: "b" * 64, raw_output: output, schema_version: "m6-test"
    )
    assert_equal 300, @transaction.field_suggestions.count

    get proposals_finance_transaction_line_items_path(@transaction, locale: "vi")
    assert_response :success
    assert_includes response.body, "Đề xuất AI theo từng dòng"
    assert_includes response.body, "Proposed item 1"
    assert_not_includes response.body, "Proposed item 100"

    get proposals_finance_transaction_line_items_path(@transaction, page: 4)
    assert_response :success
    assert_includes response.body, "Proposed item 100"
    suggestion = @transaction.field_suggestions.find_by!(field_key: "line_items.99.label")
    post accept_finance_transaction_field_suggestion_path(@transaction, suggestion),
      params: {scope: "line_items", page: 4}
    assert_response :redirect
    assert_equal "accepted", suggestion.reload.review_status
    assert_equal 0, @transaction.line_items.count
    assert_equal BigDecimal("2000000"), @transaction.reload.amount
  end

  private

  def sample_csv(count)
    CSV.generate do |csv|
      csv << %w[description amount quantity unit_price tags]
      count.times do |i|
        csv << ["Sample item #{i+1}", "1000", "1", "1000", "office"]
      end
    end
  end

  def upload(content)
    f = Tempfile.new(["finance-lines", ".csv"])
    f.binmode
    f.write(content)
    f.rewind
    Rack::Test::UploadedFile.new(f.path, "text/csv", false, original_filename: "receipt-lines.csv")
  end
end
