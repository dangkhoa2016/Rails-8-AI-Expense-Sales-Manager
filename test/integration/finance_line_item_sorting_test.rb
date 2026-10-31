require "test_helper"

class FinanceLineItemSortingTest < ActionDispatch::IntegrationTest
  setup do
    @user = User.create!(email_address: "item-sort-owner@example.test", password: "ExamplePass-2026!")
    @ws = @user.workspaces.create!(name: "Item Sorting Test")
    @tx = @ws.finance_transactions.create!(
      kind: "expense", status: "draft", currency_code: "VND",
      entry_source: "manual", created_by_id: @user.id,
      description: "Item Sorting Test", transaction_date: Date.new(2026, 10, 30),
      amount: 20_000
    )
    52.times do |i|
      @tx.line_items.create!(
        position: i, description: "Expense #{format('%02d', (52 - i))}",
        amount: (i % 3) * 1_000 + i, entry_source: "manual",
        occurred_time: (i % 4 == 0 ? nil : format("%02d:30", 8 + (i % 9))),
        location_text: (i % 5 == 0 ? nil : (i.even? ? "Zebra Store" : "Alpha Shop"))
      )
    end
    post session_path, params: {email_address: @user.email_address, password: "ExamplePass-2026!"}
    assert_response :redirect
  end

  def ids_in_table
    response.parsed_body.css("#line_item_list tbody tr").map { |el| el["id"].delete_prefix("finance_line_item_").to_i }
  end

  test "default original position and server sorting across pages both directions" do
    original_ids = @tx.line_items.order(:position, :id).pluck(:id)
    get finance_transaction_line_items_path(@tx, locale: "vi")
    assert_response :success
    assert_equal original_ids.first(25), ids_in_table
    assert_select "form.line-item-sort-controls select[name='sort'] option[value='position'][selected]", count: 1
    assert_select "table.line-item-table th[aria-sort='ascending']", count: 1
    assert_select "table.line-item-table th", count: 6
    assert_select "table.line-item-table th a.line-item-sort-link", count: 5

    sorted = @tx.line_items.order(Arel.sql("LOWER(finance_line_items.description) ASC"), :position, :id).pluck(:id)
    get finance_transaction_line_items_path(@tx, sort: "description", direction: "asc", page: 1)
    assert_response :success
    assert_equal sorted.first(25), ids_in_table
    assert_select "table.line-item-table th[aria-sort='ascending']", count: 1
    assert_select ".pagination-links a[href*='sort=description'][href*='direction=asc'][href*='page=2']", count: 1

    get finance_transaction_line_items_path(@tx, sort: "description", direction: "asc", page: 3)
    assert_response :success
    assert_equal sorted.last(2), ids_in_table

    get finance_transaction_line_items_path(@tx, sort: "amount", direction: "desc")
    expected = @tx.line_items.order(Arel.sql("finance_line_items.amount DESC"), :position, :id).limit(25).pluck(:id)
    assert_equal expected, ids_in_table
    assert_select "table.line-item-table th[aria-sort='descending']", count: 1
    assert_select ".line-item-sort-controls select[name='direction'] option[value='desc'][selected]", count: 1
  end

  test "optional time and location sort NULL last, stable tie breaking and page links" do
    %w[asc desc].each do |dir|
      get finance_transaction_line_items_path(@tx, sort: "occurred_time", direction: dir)
      assert_response :success
      assert_equal 25, ids_in_table.length
      expected = @tx.line_items.reorder(Arel.sql("finance_line_items.occurred_time #{dir.upcase} NULLS LAST"), :position, :id).limit(25).pluck(:id)
      assert_equal expected, ids_in_table

      get finance_transaction_line_items_path(@tx, sort: "location_text", direction: dir, page: 3)
      assert_response :success
      expected = @tx.line_items.reorder(Arel.sql("LOWER(NULLIF(BTRIM(finance_line_items.location_text), '')) #{dir.upcase} NULLS LAST"), :position, :id).offset(50).limit(25).pluck(:id)
      assert_equal expected, ids_in_table
    end
  end

  test "reject unknown SQL-like sorting parameters without changing stored positions" do
    baseline = @tx.line_items.order(:id).pluck(:id, :position, :amount)
    [{sort: "amount; DELETE FROM finance_line_items"}, {direction: "sideways"},
     {sort: "occurred_on"}, {sort: ["amount"]}].each do |malformed|
      get finance_transaction_line_items_path(@tx, **malformed)
      assert_response :bad_request
    end
    assert_equal baseline, @tx.line_items.order(:id).pluck(:id, :position, :amount)
  end

  test "sorted new item modal and Turbo creation retain sorting including offscreen link" do
    get new_finance_transaction_line_item_path(@tx, page: 1, sort: "amount", direction: "desc"),
      headers: {"Turbo-Frame" => "line_item_modal"}
    assert_response :success
    assert_select "input[name='sort'][value='amount']", count: 1
    assert_select "input[name='direction'][value='desc']", count: 1

    post finance_transaction_line_items_path(@tx), as: :turbo_stream, params: {
      page: 1, sort: "amount", direction: "desc",
      line_item: { description: "Small new expense", amount: "1" }
    }
    assert_response :success
    assert_select "turbo-stream[action='replace'][target='line_item_list']", count: 1
    assert_select "section#line_item_list select[name='sort'] option[value='amount'][selected]", count: 1
    assert_select "section#line_item_list tbody tr", count: 25
    assert_includes response.body, "sort=amount"
    assert_includes response.body, "View the newly added item"
    assert_equal 53, @tx.line_items.count
    assert_equal (0..52).to_a, @tx.line_items.order(:position).pluck(:position)
  end

  test "editing sorted draft resorts the whole page without altering stored positions" do
    item = @tx.line_items.order(:position).first
    get edit_finance_transaction_line_item_path(@tx, item, page: 1, sort: "amount", direction: "desc"),
      headers: {"Turbo-Frame" => "line_item_modal"}
    assert_response :success
    assert_select "input[name='sort'][value='amount']", count: 1
    patch finance_transaction_line_item_path(@tx, item), as: :turbo_stream, params: {
      page: 1, sort: "amount", direction: "desc",
      line_item: {description: "Updated amount", amount: "100000"}
    }
    assert_response :success
    assert_select "turbo-stream[action='replace'][target='line_item_list']", count: 1
    assert_select "section#line_item_list tbody tr", count: 25
    assert_select "section#line_item_list tbody tr:first-child#finance_line_item_#{item.id}", count: 1
    assert_equal 0, item.reload.position
    assert_equal BigDecimal("100000"), item.amount
  end

  test "deleting an item retains sorting in the redirect" do
    item = @tx.line_items.order(:position).first
    assert_difference "Finance::LineItem.count", -1 do
      delete finance_transaction_line_item_path(@tx, item), params: {
        sort: "amount", direction: "desc"
      }
      assert_response :redirect
    end
    assert_redirected_to finance_transaction_line_items_path(@tx,
      sort: "amount", direction: "desc")
    follow_redirect!
    assert_response :success
    assert_select "select[name='sort'] option[value='amount'][selected]", count: 1
  end

  test "name filter is case insensitive, literal, and does not modify transaction totals" do
    before = @tx.line_items.order(:id).pluck(:id, :description, :amount)
    get finance_transaction_line_items_path(@tx, locale: "vi", name: "  expense 5  ")
    assert_response :success
    expected = @tx.line_items.where("description ILIKE ?", "%expense 5%").order(:position).pluck(:id)
    assert_equal expected, ids_in_table
    assert_equal 3, expected.length
    assert_select ".line-item-filter-results", text: /3\/52/
    assert_select ".line-item-filter-controls input[name='name'][value='expense 5']", count: 1
    assert_select "table.line-item-table th", count: 6
    assert_equal before, @tx.line_items.order(:id).pluck(:id, :description, :amount)
    assert_equal BigDecimal("20000"), @tx.reload.amount

    get finance_transaction_line_items_path(@tx, name: "Expense %")
    assert_response :success
    assert_empty ids_in_table
    assert_select ".line-item-filter-results", text: /0\/52/
  end

  test "combined inclusive time and amount filters apply before sorting and paging" do
    options = {name: "expense", time_from: "09:30", time_to: "16:30",
               amount_min: "1000", amount_max: "2100",
               sort: "amount", direction: "desc"}
    expected_scope = @tx.line_items.where("description ILIKE ?", "%expense%")
      .where("occurred_time >= ? AND occurred_time <= ?", "09:30", "16:30")
      .where("amount >= ? AND amount <= ?", 1000, 2100)
    expected = expected_scope.reorder(Arel.sql("finance_line_items.amount DESC"), :position, :id).pluck(:id)
    get finance_transaction_line_items_path(@tx, **options)
    assert_response :success
    assert_equal expected.first(25), ids_in_table
    assert_select ".line-item-filter-controls input[name='time_from'][value='09:30']", count: 1
    assert_select ".line-item-filter-controls input[name='time_to'][value='16:30']", count: 1
    assert_select ".line-item-filter-controls input[name='amount_min'][value='1000']", count: 1
    assert_select "select[name='sort'] option[value='amount'][selected]", count: 1
    assert_select ".line-item-filter-results", text: /#{expected.size} of 52/
    assert_select "#line_item_list .line-item-filter-controls input[name='sort'][value='amount']"

    # Filtering only by time excludes the optional NULL time, even when
    # the item's amount/name would otherwise match.
    get finance_transaction_line_items_path(@tx, time_from: "08:30", time_to: "08:30")
    assert_response :success
    assert_equal @tx.line_items.where(occurred_time: "08:30").order(:position).pluck(:id), ids_in_table
  end

  test "pagination and header sorting preserve filter values; clear preserves sort" do
    get finance_transaction_line_items_path(@tx, name: "Expense",
      time_from: "08:30", sort: "description", direction: "asc")
    assert_response :success
    assert_equal 25, ids_in_table.length
    assert_select ".pagination-links a[href*='page=2'][href*='name=Expense'][href*='time_from=08%3A30']", count: 1
    assert_select "th a.line-item-sort-link[href*='name=Expense'][href*='sort=amount']", count: 1
    assert_select ".line-item-filter-actions a[href*='sort=description']:not([href*='name='])", count: 1
    assert_select ".line-item-sort-controls input[name='name'][value='Expense']", count: 1
    assert_select ".line-item-sort-controls input[name='time_from'][value='08:30']", count: 1

    get finance_transaction_line_items_path(@tx, name: "Expense",
      time_from: "08:30", sort: "description", direction: "asc", page: 2)
    assert_response :success
    assert_equal @tx.line_items.where("occurred_time >= ?", "08:30")
      .order(Arel.sql("LOWER(finance_line_items.description) ASC"), :position, :id)
      .offset(25).pluck(:id), ids_in_table
  end

  test "empty filters show empty result instead of changing unfiltered summary" do
    get finance_transaction_line_items_path(@tx, name: "does-not-exist", amount_min: "1")
    assert_response :success
    assert_empty ids_in_table
    assert_select ".line-item-filter-results", text: /0 of 52/
    assert_select "p.form-hint", text: /No items match/
    assert_select "#line_items_summary .kpi-value", text: /52/
  end

  test "invalid filter types, ranges and precision return bad request" do
    before = @tx.line_items.order(:id).pluck(:id, :description, :amount, :position)
    [
      {name: ["Expense"]}, {name: "x" * 201}, {time_from: "24:00"},
      {time_from: "9:30"}, {time_to: "12:40:30"},
      {time_from: "15:30", time_to: "12:30"},
      {amount_min: "-1"}, {amount_min: "1e3"},
      {amount_min: "12.345"}, {amount_max: ["100"]},
      {amount_min: "100", amount_max: "10"}
    ].each do |bad|
      get finance_transaction_line_items_path(@tx, **bad)
      assert_response :bad_request, bad.inspect
    end
    assert_equal before, @tx.line_items.order(:id).pluck(:id, :description, :amount, :position)
  end

  test "modal and Turbo edit preserve filters and refresh rows when item stops matching" do
    item = @tx.line_items.order(:position).first
    filters = {name: "Expense 52", amount_min: "0", amount_max: "99999"}
    get edit_finance_transaction_line_item_path(@tx, item, **filters),
      headers: {"Turbo-Frame" => "line_item_modal"}
    assert_response :success
    assert_select "input[name='name'][value='Expense 52']", count: 1
    assert_select "input[name='amount_max'][value='99999']", count: 1

    patch finance_transaction_line_item_path(@tx, item), as: :turbo_stream, params: {
      **filters, line_item: {description: "Changed outside filter", amount: "500"}
    }
    assert_response :success
    assert_select "turbo-stream[action='replace'][target='line_item_list']", count: 1
    assert_select "section#line_item_list tbody tr", count: 0
    assert_select "section#line_item_list .line-item-filter-results", text: /0 of 52/
    assert_equal "Changed outside filter", item.reload.description
    assert_equal 0, item.position
  end

  test "creating outside active filters includes a link to the new item outside filter" do
    get new_finance_transaction_line_item_path(@tx, name: "Some other item"),
      headers: {"Turbo-Frame" => "line_item_modal"}
    assert_response :success
    assert_select "input[name='name'][value='Some other item']", count: 1
    post finance_transaction_line_items_path(@tx), as: :turbo_stream, params: {
      name: "Some other item", line_item: {description: "New receipt expense", amount: "250"}
    }
    assert_response :success
    assert_select "section#line_item_list tbody tr", count: 0
    assert_includes response.body, "The new item does not match"
    assert_includes response.body, "View the newly added item"
    assert_equal 53, @tx.line_items.count
  end

  test "confirmed transactions may sort and remain immutable" do
    Finance::ConfirmTransaction.call(transaction: @tx, actor: @user, reviewed: true)
    positions = @tx.line_items.order(:id).pluck(:id, :position, :amount)
    get finance_transaction_line_items_path(@tx, sort: "amount", direction: "desc")
    assert_response :success
    assert_select "table.line-item-table th[aria-sort='descending']", count: 1
    assert_equal positions, @tx.line_items.order(:id).pluck(:id, :position, :amount)
    assert_select "a[href*='/line_items/new']", count: 0
  end
end
