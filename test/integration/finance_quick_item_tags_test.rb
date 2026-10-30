require "test_helper"

class FinanceQuickItemTagsTest < ActionDispatch::IntegrationTest
  setup do
    @user = User.create!(email_address: "quick-tags@example.test", password: "SecureExample-2026!")
    @workspace = @user.workspaces.create!(name: "Quick Tags")
    @other = User.create!(email_address: "foreign-tags@example.test", password: "SecureExample-2026!")
    @other_workspace = @other.workspaces.create!(name: "Foreign Tags")
    @transaction = @workspace.finance_transactions.create!(
      kind: "expense", status: "draft", entry_source: "manual", currency_code: "VND",
      created_by_id: @user.id, transaction_date: Date.new(2026,10,24),
      description: "Small purchases", amount: 100_000
    )
    post session_path,params:{email_address:@user.email_address,password:"SecureExample-2026!"}
    assert_response :redirect
  end

  test "new modal displays the shared date and leaves item time optional" do
    get new_finance_transaction_line_item_path(@transaction, locale:"vi"),
      headers: {"Turbo-Frame"=>"line_item_modal"}
    assert_response :success
    assert_select "div.quick-item-inherited-date", text: /24\/10\/2026/
    assert_select "input[name='line_item[occurred_on]']", count: 0
    assert_select "input[name='line_item[occurred_time]']", count: 1
    assert_nil css_select("input[name='line_item[occurred_time]']").first["value"]
    assert_select "input[name='line_item[quantity]'][value='1.0'], input[name='line_item[quantity]'][value='1']"
    assert_select "div[data-controller='line-item-entry']", count: 1
    assert_select "input[name='line_item[unit_price]'][data-line-item-entry-target='unitPrice']"
    assert_select "input[name='line_item[amount]'][data-line-item-entry-target='amount']"
    assert_select "input[name='line_item[tag_selection]'][value='1']"
    assert_select "input[name='line_item[tag_ids][]']", minimum: 1
    assert_select "input[name='line_item[new_tags]']"
    assert_select "details.quick-item-optional", count: 1
  end

  test "draft with unknown date permits items but never invents a day or time" do
    @transaction.update!(transaction_date:nil)
    get new_finance_transaction_line_item_path(@transaction)
    assert_response :success
    assert_select "input[name='line_item[occurred_on]']", count: 0
    post finance_transaction_line_items_path(@transaction), as: :turbo_stream,
      params:{line_item:{description:"Taxi",amount:"30000",quantity:"1",tag_selection:"1"}}
    assert_response :success
    item=@transaction.line_items.sole
    assert_nil item.occurred_on
    assert_nil item.effective_date
    assert_nil item.occurred_time
  end

  test "amount is computed server-side from quantity and unit price, never trusting stale submitted total" do
    assert_difference "Finance::LineItem.count",1 do
      post finance_transaction_line_items_path(@transaction), as: :turbo_stream,
        params:{line_item:{description:"Paper",amount:"1",quantity:"2.5",unit_price:"12000.20",
                           tag_selection:"1"}}
      assert_response :success
    end
    item=@transaction.line_items.sole
    assert_equal BigDecimal("30000.50"), item.amount
    assert_equal BigDecimal("2.5"), item.quantity
    assert_equal BigDecimal("12000.20"), item.unit_price
    assert_equal BigDecimal("30000.50"),@transaction.reload.amount
    assert_select "turbo-stream[action='replace'][target='line_items_summary']", count: 1

    patch finance_transaction_line_item_path(@transaction,item), as: :turbo_stream,
      params:{line_item:{amount:"2",quantity:"3",unit_price:"12000.20",tag_selection:"1"}}
    assert_response :success
    assert_equal BigDecimal("36000.60"), item.reload.amount
    assert_equal "Paper",item.description
  end

  test "multiple existing tags plus newly created tag are saved atomically and shown in both locales" do
    Finance::Category.bootstrap!(@workspace.id)
    food=@workspace.finance_categories.find_by!(key:"food")
    office=@workspace.finance_categories.find_by!(key:"office")
    assert_difference "Finance::LineItem.count",1 do
      assert_difference "Finance::Category.count",1 do
        post finance_transaction_line_items_path(@transaction), as: :turbo_stream,
          params:{line_item:{description:"Tea",quantity:"2",unit_price:"5000",amount:"0",
                             tag_selection:"1",tag_ids:[food.id.to_s,office.id.to_s],
                             new_tags:"Buổi sáng"}}
        assert_response :success
      end
    end
    item=@transaction.line_items.sole
    assert_equal BigDecimal("10000"),item.amount
    assert_equal 3,item.tags.count
    assert_equal "food",item.category
    new_tag=@workspace.finance_categories.find_by!(name_vi:"Buổi sáng")
    assert_equal "Buổi sáng",new_tag.name_en # explicit fallback, not AI translation
    assert_equal [food.id,office.id,new_tag.id].sort,item.tags.pluck(:id).sort
    assert_includes response.body,"Buổi sáng"
    assert_includes response.body,"Food &amp; drinks"
    get finance_transaction_line_items_path(@transaction,locale:"en")
    assert_response :success
    assert_includes response.body,"Food &amp; drinks"
    assert_includes response.body,"Buổi sáng"
    get finance_categories_path(locale:"vi")
    assert_includes response.body,"Buổi sáng"

    # A second item reuses existing tag name instead of creating another.
    assert_no_difference "Finance::Category.count" do
      post finance_transaction_line_items_path(@transaction), as: :turbo_stream,
        params:{line_item:{description:"Coffee",amount:"8000",
                           tag_selection:"1",new_tags:"Buổi sáng"}}
      assert_response :success
    end
    assert_equal [new_tag.id],@transaction.line_items.order(:id).last.tags.pluck(:id)
  end

  test "invalid and cross workspace tags roll back item and tag creation" do
    foreign=Finance::Category.create!(workspace:@other_workspace,key:"secret",name_en:"Secret",name_vi:"Bí mật")
    Finance::Category.bootstrap!(@workspace.id)
    before=[Finance::LineItem.count,Finance::Category.count,Finance::LineItemTag.count,Finance::AuditEvent.count]
    post finance_transaction_line_items_path(@transaction), as: :turbo_stream,
      params:{line_item:{description:"Tampered",amount:"200",tag_selection:"1",
                         tag_ids:[foreign.id],new_tags:"DemoTag"}}
    assert_response :unprocessable_entity
    assert_equal before,[Finance::LineItem.count,Finance::Category.count,Finance::LineItemTag.count,Finance::AuditEvent.count]
    assert_select "turbo-stream[action='update'][target='line_item_modal']"
    assert_includes response.body, 'role="alert"'

    post finance_transaction_line_items_path(@transaction), as: :turbo_stream,
      params:{line_item:{description:"Bad tag",amount:"100",tag_selection:"1",
                         new_tags:"x"}}
    assert_response :unprocessable_entity
    assert_equal before,[Finance::LineItem.count,Finance::Category.count,Finance::LineItemTag.count,Finance::AuditEvent.count]
  end

  test "editing tags changes only draft links; confirmed tag links DB trigger prevents mutation" do
    Finance::Category.bootstrap!(@workspace.id)
    food=@workspace.finance_categories.find_by!(key:"food")
    office=@workspace.finance_categories.find_by!(key:"office")
    item=@transaction.line_items.create!(description:"Example",amount:30000,position:0,entry_source:"manual",occurred_on:Date.new(2026,10,24))
    patch finance_transaction_line_item_path(@transaction,item), as: :turbo_stream,
      params:{line_item:{description:"Example",amount:"30000",tag_selection:"1",tag_ids:[food.id]}}
    assert_response :success
    assert_equal [food.id],item.tags.pluck(:id)
    patch finance_transaction_line_item_path(@transaction,item), as: :turbo_stream,
      params:{line_item:{description:"Example",amount:"30000",tag_selection:"1",tag_ids:[office.id]}}
    assert_response :success
    assert_equal [office.id],item.reload.tags.pluck(:id)
    assert_equal "office",item.category
    Finance::ConfirmTransaction.call(transaction:@transaction,actor:@user,reviewed:true)
    assert_raises(ActiveRecord::StatementInvalid) do
      Finance::LineItemTag.transaction(requires_new: true) do
        Finance::LineItemTag.connection.execute(
          "DELETE FROM finance_line_item_tags WHERE line_item_id = #{item.id}")
      end
    end
    assert_equal [office.id],item.tags.pluck(:id)
    assert_equal BigDecimal("30000"),item.amount

    patch finance_transaction_line_item_path(@transaction,item), as: :turbo_stream,
      params:{line_item:{description:"Adjusted via correction",amount:"12000",
                         tag_selection:"1",tag_ids:[food.id]},
              correction_reason:"The item was assigned the wrong tags and amount."}
    assert_response :success
    assert_equal "office",item.reload.category
    replacement=@transaction.reload.correction_as_original.replacement_transaction
    assert replacement.draft?
    copied=replacement.line_items.find_by!(position:0)
    assert_equal "food",copied.category
    assert_equal [food.id],copied.tags.pluck(:id)
    assert_equal BigDecimal("30000"),item.amount
  end
end
