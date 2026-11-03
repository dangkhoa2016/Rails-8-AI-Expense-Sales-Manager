require "test_helper"
require "csv"

class FinanceItemContextTest < ActionDispatch::IntegrationTest
  setup do
    @user = User.create!(email_address: "item-context@example.test", password: "SampleSecure-2026!")
    @workspace = @user.workspaces.create!(name: "Individual Item Context")
    @tx = @workspace.finance_transactions.create!(
      kind: "expense", status: "draft", currency_code: "VND",
      entry_source: "manual", created_by_id: @user.id,
      description: "Food and stationery", transaction_date: Date.new(2026, 4, 26),
      amount: 115_000
    )
    post session_path, params: {email_address: @user.email_address, password: "SampleSecure-2026!"}
    assert_response :redirect
  end

  test "editing item uses transaction date and permits optional item time and location" do
    post finance_transaction_line_items_path(@tx), params: {line_item: {
      description: "Bánh mì ngọt", amount: "30000", occurred_on: "2026-04-27",
      occurred_time: "08:12", location_text: "Tiệm bánh giả lập"
    }}
    assert_response :redirect
    item = @tx.line_items.sole
    assert_nil item.occurred_on
    assert_equal Date.new(2026, 4, 26), item.effective_date
    assert_equal "08:12", item.occurred_time.strftime("%H:%M")
    assert_equal "Tiệm bánh giả lập", item.location_text
    get edit_finance_transaction_line_item_path(@tx, item, locale: "vi")
    assert_response :success
    assert_select 'input[name="line_item[description]"][value="Bánh mì ngọt"]'
    assert_select 'input[name="line_item[occurred_on]"]', count: 0
    assert_select 'div.quick-item-inherited-date', text: /26\/04\/2026/
    assert_select 'input[name="line_item[occurred_time]"][type="time"]'
    assert_select 'input[name="line_item[location_text]"]'

    patch finance_transaction_line_item_path(@tx,item), params: {line_item: {
      description: "Bánh mì ngọt và sữa", amount: "45000",
      occurred_on: "2026-04-27", occurred_time: "", location_text: "   "
    }}
    assert_response :redirect
    item.reload
    assert_equal "Bánh mì ngọt và sữa", item.description
    assert_equal BigDecimal("45000"), item.amount
    assert_nil item.occurred_on
    assert_equal Date.new(2026,4,26), item.effective_date
    assert_nil item.occurred_time
    assert_nil item.location_text
    assert_equal BigDecimal("45000"), @tx.reload.amount

    get finance_transaction_line_items_path(@tx,locale:"vi")
    assert_response :success
    assert_select ".line-items-date-context time", text: /26\/04\/2026/
    assert_select "tr#finance_line_item_#{item.id} td.line-cell-date", count: 0
  end

  test "CSV inherits one transaction date and preserves time and location when supplied" do
    csv = CSV.generate do |rows|
      rows << %w[description amount quantity unit_price tags occurred_time location_text]
      rows << ["Sweet bread", "30000", "1", "30000", "food", "08:12", "Example bakery"]
      rows << ["A4 paper", "85000", "1", "85000", "office", "", ""]
    end
    assert_difference "Finance::LineItem.count", 2 do
      post import_finance_transaction_line_items_path(@tx), params: { file: upload(csv) }
      assert_response :redirect
    end
    assert_equal 1, @tx.line_import_batches.count
    bread,paper = @tx.line_items.order(:position)
    assert_nil bread.occurred_on
    assert_nil paper.occurred_on
    assert_equal Date.new(2026,4,26), bread.effective_date
    assert_equal Date.new(2026,4,26), paper.effective_date
    assert_equal "08:12", bread.occurred_time.strftime("%H:%M")
    assert_equal "Example bakery", bread.location_text
    assert_nil paper.occurred_time
    assert_nil paper.location_text
    assert_no_difference "Finance::LineItem.count" do
      post import_finance_transaction_line_items_path(@tx), params: {file: upload(csv)}
      assert_response :redirect
    end
  end

  test "CSV bad legacy date or invalid time rejects all items" do
    ["2026-02-30", "26/04/2026", "2026-04-27"].each do |bad_date|
      csv = "description,amount,occurred_on,occurred_time\nBread,30000,2026-04-26,08:12\nPaper,85000,#{bad_date},09:00\n"
      assert_no_difference "Finance::LineItem.count" do
        post import_finance_transaction_line_items_path(@tx), params: {file: upload(csv)}
        assert_response :redirect
      end
      assert_equal 0, @tx.line_import_batches.count
    end
    csv = "description,amount,occurred_time\nBread,30000,25:59\n"
    assert_no_difference "Finance::LineItem.count" do
      post import_finance_transaction_line_items_path(@tx), params: {file: upload(csv)}
      assert_response :redirect
    end
  end

  test "confirmed item remains immutable and targeted correction creates editable item draft" do
    item = @tx.line_items.create!(
      position: 0, description: "Original bread", amount: 30_000, entry_source: "manual",
      occurred_on: Date.new(2026,4,26), occurred_time: "08:12", location_text: "Original bakery"
    )
    Finance::ConfirmTransaction.call(transaction: @tx, actor: @user, reviewed: true)

    get finance_transaction_line_items_path(@tx, locale:"vi")
    assert_response :success
    assert_select "a.line-item-edit-action .line-item-action-label", text: "Sửa"
    assert_select "a.line-item-edit-action[aria-label^='Sửa chi tiết khoản:']", count: 1
    assert_select "a[href*=\'/line_items/#{item.id}/edit\']", minimum: 1
    get edit_finance_transaction_line_item_path(@tx,item)
    assert_response :success
    assert_includes response.body, "Lý do điều chỉnh"
    patch finance_transaction_line_item_path(@tx,item), params: {line_item:{amount:"1"}}
    assert_response :unprocessable_entity
    assert_nil @tx.reload.correction_as_original

    get edit_finance_transaction_line_item_path(@tx, item, locale:"vi")
    assert_response :success
    assert_includes response.body, "Lý do điều chỉnh"

    assert_difference "Finance::Correction.count", 1 do
      post finance_transaction_correction_path(@tx),
        params: {reason:"Correct the price and location on the bread item.",
          line_item_id:item.id}
      assert_response :redirect
    end
    correction = @tx.reload.correction_as_original
    replacement = correction.replacement_transaction
    assert replacement.draft?
    new_item = replacement.line_items.find_by!(position:0)
    assert_redirected_to edit_finance_transaction_line_item_path(replacement,new_item)
    assert_equal item.occurred_on, new_item.occurred_on
    assert_equal item.occurred_time.strftime("%H:%M"), new_item.occurred_time.strftime("%H:%M")
    assert_equal "Original bakery", new_item.location_text

    patch finance_transaction_line_item_path(replacement,new_item), params: {line_item:{
      description:"Corrected bread", amount:"35000", occurred_on:"2026-04-27",
      occurred_time:"09:23",location_text:"Corrected market"
    }}
    assert_response :redirect
    assert_equal "Original bread", item.reload.description
    assert_equal BigDecimal("30000"), item.amount
    assert_equal "Corrected bread", new_item.reload.description
    assert_equal "Corrected market", new_item.location_text
    assert_equal BigDecimal("35000"), replacement.reload.amount
  end

  private

  def upload(content)
    file = Tempfile.new(["individual-context", ".csv"])
    file.binmode
    file.write(content)
    file.rewind
    Rack::Test::UploadedFile.new(file.path, "text/csv", false,
      original_filename: "itemized.csv")
  end
end
