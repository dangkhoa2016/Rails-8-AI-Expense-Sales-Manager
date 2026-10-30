require "test_helper"
require "csv"

class FinanceTagsOnlySchemaTest < ActionDispatch::IntegrationTest
  setup do
    @user = User.create!(email_address: "tags-only-schema@example.test", password: "StrongPass-2026!")
    @ws = @user.workspaces.create!(name: "Tags Only Workspace")
    Finance::Tag.bootstrap!(@ws.id)
    @food = @ws.finance_tags.find_by!(key: "food")
    @office = @ws.finance_tags.find_by!(key: "office")
    post session_path, params: {email_address: @user.email_address, password: "StrongPass-2026!"}
    assert_response :redirect
  end

  test "Tags are the only live classification schema; no category table, column or controller route" do
    assert_not Finance::Transaction.column_names.include?("category")
    assert_not Finance::LineItem.column_names.include?("category")
    assert_not ActiveRecord::Base.connection.data_source_exists?("finance_categories")
    assert ActiveRecord::Base.connection.data_source_exists?("finance_tags")
    assert Finance::TransactionTag.column_names.include?("tag_id")
    assert Finance::LineItemTag.column_names.include?("tag_id")
    assert_not Finance::TransactionTag.column_names.include?("category_id")
    assert_not Finance::LineItemTag.column_names.include?("category_id")
    assert_raises(ActionController::RoutingError) do
      Rails.application.routes.recognize_path("/finance/categories", method: :get)
    end
    get finance_tags_path(locale: "vi")
    assert_response :success
    assert_select "h1", text: /Quản lý Tags/
    assert_select "form input[name='finance_tag[key]']", count: 1
  end

  test "multi-tagged confirmed totals and CSV stay single-counted, with only Tags column" do
    tx = @ws.finance_transactions.create!(
      kind: "expense", status: "draft", currency_code: "VND",
      created_by_id: @user.id, transaction_date: Date.new(2026, 10, 30),
      amount: 31_000, description: "Verified Tag accounting", entry_source: "manual",
      line_total_managed: true
    )
    first = tx.line_items.create!(description: "Paper", amount: 11_000, position: 0, entry_source: "manual")
    second = tx.line_items.create!(description: "Snacks", amount: 20_000, position: 1, entry_source: "manual")
    Finance::TransactionTagging.apply!(transaction: tx, actor: @user,
      tag_ids: [@office.id, @food.id], new_names: "")
    Finance::ItemTagging.apply!(item: first, workspace_id: @ws.id,
      tag_ids: [@office.id, @food.id], new_names: "")
    Finance::ItemTagging.apply!(item: second, workspace_id: @ws.id,
      tag_ids: [@food.id, @office.id], new_names: "")
    Finance::ConfirmTransaction.call(transaction: tx, actor: @user, reviewed: true)
    selected = Finance::Transaction.for_workspace(@ws.id).effective_confirmed
      .where(kind: "expense", transaction_date: Date.new(2026, 10, 1)..Date.new(2026, 10, 31))
    assert_equal BigDecimal("31000"), Finance::TagBreakdown.call(transactions: selected, item_level: false).values.sum
    item_allocation = Finance::TagBreakdown.call(transactions: selected, item_level: true)
    assert_equal BigDecimal("31000"), item_allocation.values.sum
    assert_equal BigDecimal("11000"), item_allocation["office"]
    assert_equal BigDecimal("20000"), item_allocation["food"]
    assert_equal 2, tx.tags.size
    get finance_reports_path(month: "2026-10", locale: "vi")
    assert_response :success
    assert_not_includes response.body, "Danh mục"

    get finance_reports_export_path(month: "2026-10")
    assert_response :success
    parsed = CSV.parse(response.body, headers: true)
    assert_includes parsed.headers, "Tags"
    assert_not_includes parsed.headers, "Category"
    assert_equal "office;food", parsed.first["Tags"]
  end

  test "CSV rejects old category header instead of silently misclassifying; accepts Tags" do
    tx = @ws.finance_transactions.create!(
      kind: "expense", status: "draft", currency_code: "VND",
      created_by_id: @user.id, transaction_date: Date.new(2026, 10, 30),
      amount: 0, entry_source: "manual", description: "Import Tags"
    )
    upload = ->(body) {
      f = Tempfile.new(["tags-schema", ".csv"])
      f.write(body)
      f.flush
      Rack::Test::UploadedFile.new(f.path, "text/csv", false, original_filename: "items.csv")
    }
    assert_no_difference "Finance::LineItem.count" do
      post import_finance_transaction_line_items_path(tx), params: {
        file: upload.call("description,amount,category\nPaper,6000,office\n")}
      assert_response :redirect
    end
    assert_difference "Finance::LineItem.count", 1 do
      post import_finance_transaction_line_items_path(tx), params: {
        file: upload.call("description,amount,tags\nPaper,6000,office\n")}
      assert_response :redirect
    end
    assert_equal ["office"], tx.line_items.sole.tags.pluck(:key)
    assert_equal BigDecimal("6000"), tx.reload.amount
  end
end
