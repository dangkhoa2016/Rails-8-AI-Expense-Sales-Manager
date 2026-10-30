require "test_helper"

class FinanceCategoriesTest < ActionDispatch::IntegrationTest
  setup do
    @user = User.create!(email_address: "categories-owner@example.test", password: "ExampleSecure-2026!")
    @workspace = @user.workspaces.create!(name: "Category Workspace")
    @other = User.create!(email_address: "categories-other@example.test", password: "ExampleSecure-2026!")
    @other_workspace = @other.workspaces.create!(name: "Other Workspace")
    post session_path, params: {email_address: @user.email_address, password: "ExampleSecure-2026!"}
    assert_response :redirect
  end

  test "category CRUD with exact English and Vietnamese display names, stable key" do
    get finance_categories_path(locale: "vi")
    assert_response :success
    assert_select "h1", text: /Quản lý Tags/
    assert_select "aside .category-editor label.tag-status-toggle input[type='checkbox']", count: 0
    assert_select "a[href='#{finance_tags_path}']", text: /Tags/
    assert @workspace.finance_categories.exists?(key: "food")

    assert_difference "Finance::Category.count", 1 do
      post finance_categories_path, params: {finance_category: {
        key: "bakery", name_en: "Baked goods", name_vi: "Bánh ngọt"
      }}
      assert_response :redirect
    end
    record = @workspace.finance_categories.find_by!(key: "bakery")
    get finance_categories_path(locale: "vi")
    assert_includes response.body, "Bánh ngọt"
    get new_finance_transaction_path(kind: "expense",locale: "vi")
    assert_response :success
    assert_select "input[name='transaction_tag_ids[]'][value='#{record.id}'] + span", text: "Bánh ngọt"
    get new_finance_transaction_path(locale: "en")
    assert_select "input[name='transaction_tag_ids[]'][value='#{record.id}'] + span", text: "Baked goods"

    get edit_finance_category_path(record,locale:"vi")
    assert_response :success
    assert_select "aside .category-editor label.tag-status-toggle input[type='checkbox'][name='finance_category[active]']", count: 1
    assert_select "input[name='finance_category[key]'][readonly]"
    patch finance_category_path(record), params: {finance_category: {
      name_en: "Bakery & pastry", name_vi: "Tiệm bánh", active: "1"
    }}
    assert_response :redirect
    assert_equal "Tiệm bánh", record.reload.name_vi
    get new_finance_transaction_path(locale:"en")
    assert_select "input[name='transaction_tag_ids[]'][value='#{record.id}'] + span", text: "Bakery & pastry"

    assert_difference "Finance::Category.count", -1 do
      delete finance_category_path(record)
      assert_response :redirect
    end
  end

  test "deleting referenced category archives instead of breaking historical reports" do
    Finance::Category.bootstrap!(@workspace.id)
    category = @workspace.finance_categories.find_by!(key: "office")
    tx = @workspace.finance_transactions.create!(
      kind: "expense", status: "draft", currency_code: "VND", entry_source: "manual",
      created_by_id: @user.id, transaction_date: Date.new(2026, 10, 29),
      description: "Paper", amount: 15000, category: "office"
    )
    Finance::ConfirmTransaction.call(transaction: tx, actor: @user, reviewed: true)
    assert_no_difference "Finance::Category.count" do
      delete finance_category_path(category)
      assert_response :redirect
    end
    assert_not category.reload.active?
    assert_equal "office", tx.reload.category
    get new_finance_transaction_path(locale: "en")
    assert_select "input[name='transaction_tag_ids[]'][value='#{category.id}']", count: 0
    get finance_transaction_path(tx,locale:"vi")
    assert_response :success
    assert_includes response.body, "Văn phòng phẩm"
    get finance_reports_path(month:"2026-10",locale:"en")
    assert_response :success
    assert_includes response.body, "Office supplies"
    patch finance_category_path(category), params:{finance_category:{name_en:"Office & paper",name_vi:"Đồ dùng văn phòng",active:"1"}}
    assert_response :redirect
    assert category.reload.active?
    get new_finance_transaction_path(locale:"vi")
    assert_select "input[name='transaction_tag_ids[]'][value='#{category.id}'] + span", text: "Đồ dùng văn phòng"
  end

  test "legacy free-text category is available for selection and translated without changing ledger" do
    tx = @workspace.finance_transactions.create!(
      kind: "expense", status: "draft", currency_code: "VND", entry_source: "manual",
      created_by_id: @user.id, amount: 2000,
      transaction_date: Date.new(2026,10,22),
      description: "Legacy example", category:"legacy_custom")
    get finance_categories_path(locale: "vi")
    assert_response :success
    cat = @workspace.finance_categories.find_by!(key: "legacy_custom")
    assert_equal "Legacy custom", cat.name_en
    get edit_finance_category_path(cat)
    assert_response :success
    get edit_finance_transaction_path(tx,locale:"en")
    assert_response :success
    assert_select "input[name='transaction_tag_ids[]'][value='#{cat.id}'][checked]"
  end

  test "other tenant cannot edit delete or see categories" do
    post finance_categories_path, params:{finance_category:{key:"private_key",name_en:"Private expense",name_vi:"Danh mục riêng"}}
    category = @workspace.finance_categories.find_by!(key:"private_key")
    delete session_path
    post session_path, params:{email_address:@other.email_address,password:"ExampleSecure-2026!"}
    get finance_categories_path(locale:"en")
    assert_response :success
    assert_not_includes response.body, "Private expense"
    get edit_finance_category_path(category)
    assert_response :not_found
    patch finance_category_path(category),params:{finance_category:{name_en:"Hacked"}}
    assert_response :not_found
    delete finance_category_path(category)
    assert_response :not_found
    assert_equal "Private expense", category.reload.name_en
  end

  test "duplicate and invalid categories rejected; cannot mutate key" do
    Finance::Category.bootstrap!(@workspace.id)
    assert_no_difference "Finance::Category.count" do
      post finance_categories_path, params:{finance_category:{key:"food",name_en:"Duplicate",name_vi:"Trùng"}}
      assert_response :unprocessable_entity
      post finance_categories_path, params:{finance_category:{key:"bad key!",name_en:"Bad",name_vi:"Sai"}}
      assert_response :unprocessable_entity
    end
    c = @workspace.finance_categories.find_by!(key:"food")
    patch finance_category_path(c),params:{finance_category:{key:"hijack",name_en:"Food update",name_vi:"Cập nhật"}}
    assert_response :redirect
    assert_equal "food",c.reload.key
  end
end
