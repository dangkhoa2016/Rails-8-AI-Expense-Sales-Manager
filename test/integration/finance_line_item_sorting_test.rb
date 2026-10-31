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
    assert_select "form.line-item-sort-controls", count: 0
    assert_select "form.line-item-filter-controls", count: 1
    assert_select "details.line-item-filter-disclosure[open]", count: 1
    assert_select "#line_item_results[tabindex='-1']", count: 1
    assert_select ".line-item-filter-toggle", text: /Chưa áp dụng/, count: 1
    assert_select "form.line-item-filter-controls[action$='#line_item_results']", count: 1
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
    assert_select ".line-item-filter-controls input[name='direction'][value='desc']", count: 1
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
    assert_select "turbo-stream[action='replace'][target='line_item_list'] section#line_item_list .line-item-filter-controls", count: 0
    assert_select "section#line_item_list tbody tr", count: 25
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
    assert_select ".line-item-filter-controls input[name='sort'][value='amount']", count: 1
  end

  test "name filter is case insensitive, literal, and does not modify transaction totals" do
    before = @tx.line_items.order(:id).pluck(:id, :description, :amount)
    get finance_transaction_line_items_path(@tx, locale: "vi", name: "  expense 5  ")
    assert_response :success
    expected = @tx.line_items.where("description ILIKE ?", "%expense 5%").order(:position).pluck(:id)
    assert_equal expected, ids_in_table
    assert_equal 3, expected.length
    assert_select ".line-item-filter-results", text: /3\/52/
    assert_select ".line-item-filter-toggle .line-item-filter-count", text: /1 điều kiện/, count: 1
    assert_select "details.line-item-filter-disclosure[open]", count: 1
    assert_select ".line-item-filter-clear[href$='#line_item_results']", count: 1
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
    assert_select ".line-item-filter-controls input[name='sort'][value='amount']", count: 1
    assert_select ".line-item-filter-results", text: /#{expected.size} of 52/
    assert_select ".line-items-filter-rail .line-item-filter-controls input[name='sort'][value='amount']"

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
    assert_select ".line-item-filter-clear[href*='sort=description']:not([href*='name='])", count: 1
    assert_select ".line-item-filter-controls input[name='name'][value='Expense']", count: 1
    assert_select ".line-item-filter-controls input[name='time_from'][value='08:30']", count: 1

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

  test "multi-tag OR filter is item-scoped and avoids duplicate amounts for double-tagged rows" do
    food = create_filter_tag("food_test")
    office = create_filter_tag("office_test")
    first, second, third = @tx.line_items.order(:position).limit(3).to_a
    assign_filter_tag(first, food)
    assign_filter_tag(first, office)
    assign_filter_tag(second, food)
    assign_filter_tag(third, office)
    original_amounts = @tx.line_items.order(:id).pluck(:id, :amount)

    get finance_transaction_line_items_path(@tx, locale: "en",
      tag_ids: [food.id.to_s, office.id.to_s, office.id.to_s])
    assert_response :success
    assert_equal [first.id, second.id, third.id], ids_in_table
    assert_select ".line-item-filter-results", text: /3 of 52/
    assert_select ".line-item-filter-results", text: /3,003/
    assert_select ".finance-tags-filter input[name='tag_ids[]'][checked]", count: 2
    assert_select ".line-item-filter-count", text: /2 selected/, count: 1
    assert_select ".line-item-filter-controls .finance-tags-disclosure[open]", count: 1
    assert_select ".line-item-sort-controls", count: 0
    assert_equal original_amounts, @tx.line_items.order(:id).pluck(:id, :amount)
  end

  test "selected item Tags AND existing text time and amount filters" do
    food = create_filter_tag("food_test")
    office = create_filter_tag("office_test")
    first, second = @tx.line_items.order(:position).limit(2).to_a
    assign_filter_tag(first, food)
    assign_filter_tag(second, office)
    get finance_transaction_line_items_path(@tx, locale: "vi",
      tag_ids: [food.id.to_s, office.id.to_s], name: "Expense 51",
      time_from: "09:30", time_to: "09:30", amount_min: "1001",
      amount_max: "1001", sort: "amount", direction: "desc")
    assert_response :success
    assert_equal [second.id], ids_in_table
    assert_select ".line-item-filter-results", text: /1\/52/
    assert_select ".finance-tags-filter input[name='tag_ids[]'][checked]", count: 2
    assert_select ".line-item-filter-controls input[name='sort'][value='amount']", count: 1
    assert_select "table.line-item-table th[aria-sort='descending']", count: 1
  end

  test "archived Tags remain filterable for historical rows" do
    archived = create_filter_tag("archived_test")
    item = @tx.line_items.order(:position).first
    assign_filter_tag(item, archived)
    archived.update!(active: false)
    get finance_transaction_line_items_path(@tx, tag_ids: [archived.id.to_s])
    assert_response :success
    assert_equal [item.id], ids_in_table
    assert_select ".finance-tags-filter small", text: /Archived/
  end

  test "unknown foreign oversized and malformed Tag selections fail closed" do
    other_user = User.create!(email_address: "item-filter-foreign@example.test", password: "ExamplePass-2026!")
    other_ws = other_user.workspaces.create!(name: "Foreign Item Filtering")
    foreign = Finance::Tag.create!(workspace: other_ws, key: "foreign_test",
      name_en: "Foreign", name_vi: "Ngoài", active: true)
    owned = create_filter_tag("owned_test")
    before = @tx.line_items.order(:id).pluck(:id, :amount, :position)
    [
      {tag_ids: foreign.id.to_s},
      {tag_ids: [foreign.id.to_s]},
      {tag_ids: [owned.id.to_s, foreign.id.to_s]},
      {tag_ids: ["-1"]}, {tag_ids: ["1 OR 1=1"]},
      {tag_ids: [owned.id.to_s] * 51},
      {tag_ids: {x: owned.id.to_s}}
    ].each do |bad|
      get finance_transaction_line_items_path(@tx, **bad)
      assert_response :bad_request, bad.inspect
    end
    assert_equal before, @tx.line_items.order(:id).pluck(:id, :amount, :position)
  end

  test "Tag selections survive pagination, heading sort and reset with no sort controls" do
    tag = create_filter_tag("page_test")
    @tx.line_items.order(:position).limit(30).each { |item| assign_filter_tag(item, tag) }
    get finance_transaction_line_items_path(@tx, tag_ids: [tag.id.to_s],
      sort: "amount", direction: "desc")
    assert_response :success
    assert_equal 25, ids_in_table.length
    assert_select ".pagination-links a[href*='tag_ids%5B%5D='][href*='page=2']", count: 1
    assert_select "th a.line-item-sort-link[href*='tag_ids%5B%5D='][href*='sort=description']", count: 1
    assert_select ".line-item-filter-clear[href*='sort=amount']:not([href*='tag_ids'])", count: 1
    assert_select ".line-item-sort-controls", count: 0
    get finance_transaction_line_items_path(@tx, tag_ids: [tag.id.to_s], page: 2,
      sort: "amount", direction: "desc")
    assert_response :success
    assert_equal 5, ids_in_table.length
    assert_select ".finance-tags-filter input[name='tag_ids[]'][checked]", count: 1
  end

  test "Tag filter survives modal GET and Turbo item edit that no longer matches" do
    tag = create_filter_tag("modal_test")
    item = @tx.line_items.order(:position).first
    assign_filter_tag(item, tag)
    get edit_finance_transaction_line_item_path(@tx, item, tag_ids: [tag.id.to_s]),
      headers: {"Turbo-Frame" => "line_item_modal"}
    assert_response :success
    assert_select "dialog input[name='tag_ids[]'][value='#{tag.id}']", count: 1
    patch finance_transaction_line_item_path(@tx, item), as: :turbo_stream,
      params: {tag_ids: [tag.id.to_s],
        line_item: {description: "Updated", amount: "50",
          tag_selection: "1", tag_ids: []}}
    assert_response :success
    assert_select "turbo-stream[action='replace'][target='line_item_list']", count: 1
    assert_select "section#line_item_list tbody tr", count: 0
    assert_select "section#line_item_list .line-item-filter-results", text: /0 of 52/
    assert_equal 0, item.reload.tags.count
  end

  def create_filter_tag(key)
    Finance::Tag.create!(workspace: @ws, key: key, name_en: key, name_vi: key, active: true)
  end

  def assign_filter_tag(item, tag)
    Finance::LineItemTag.create!(line_item: item, tag: tag)
  end

  test "compact filter disclosure and result anchor remain visible for zero matches" do
    get finance_transaction_line_items_path(@tx, name: "No such item", tag_ids: [])
    assert_response :success
    assert_select "details.line-item-filter-disclosure[open]", count: 1
    assert_select "summary.line-item-filter-toggle", count: 1
    assert_select "form.line-item-filter-controls[action$='#line_item_results']", count: 1
    assert_select "#line_item_results .line-item-filter-results", count: 1
    assert_select "#line_item_results .form-hint", text: /No items match/
    assert_select ".line-item-filter-clear[href$='#line_item_results']", count: 1
    assert_select ".line-item-filter-results", text: /0 of 52/
    assert_select "#line_items_summary .kpi-value", text: /52/
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
