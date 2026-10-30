require "test_helper"

class FinanceTagsTest < ActionDispatch::IntegrationTest
  setup do
    @user = User.create!(email_address: "categories-owner@example.test", password: "ExampleSecure-2026!")
    @workspace = @user.workspaces.create!(name: "Category Workspace")
    @other = User.create!(email_address: "categories-other@example.test", password: "ExampleSecure-2026!")
    @other_workspace = @other.workspaces.create!(name: "Other Workspace")
    post session_path, params: {email_address: @user.email_address, password: "ExampleSecure-2026!"}
    assert_response :redirect
  end

  test "category CRUD with exact English and Vietnamese display names, stable key" do
    get finance_tags_path(locale: "vi")
    assert_response :success
    assert_select "h1", text: /Quản lý Tags/
    assert_select "aside .tag-editor label.tag-status-toggle input[type='checkbox']", count: 0
    assert_select "a[href='#{finance_tags_path}']", text: /Tags/
    assert @workspace.finance_tags.exists?(key: "food")

    assert_difference "Finance::Tag.count", 1 do
      post finance_tags_path, params: {finance_tag: {
        key: "bakery", name_en: "Baked goods", name_vi: "Bánh ngọt"
      }}
      assert_response :redirect
    end
    record = @workspace.finance_tags.find_by!(key: "bakery")
    get finance_tags_path(locale: "vi")
    assert_includes response.body, "Bánh ngọt"
    get new_finance_transaction_path(kind: "expense",locale: "vi")
    assert_response :success
    assert_select "input[name='transaction_tag_ids[]'][value='#{record.id}'] + span", text: "Bánh ngọt"
    get new_finance_transaction_path(locale: "en")
    assert_select "input[name='transaction_tag_ids[]'][value='#{record.id}'] + span", text: "Baked goods"

    get edit_finance_tag_path(record,locale:"vi")
    assert_response :success
    assert_select "aside .tag-editor label.tag-status-toggle input[type='checkbox'][name='finance_tag[active]']", count: 1
    assert_select "input[name='finance_tag[key]'][readonly]"
    patch finance_tag_path(record), params: {finance_tag: {
      name_en: "Bakery & pastry", name_vi: "Tiệm bánh", active: "1"
    }}
    assert_response :redirect
    assert_equal "Tiệm bánh", record.reload.name_vi
    get new_finance_transaction_path(locale:"en")
    assert_select "input[name='transaction_tag_ids[]'][value='#{record.id}'] + span", text: "Bakery & pastry"

    assert_difference "Finance::Tag.count", -1 do
      delete finance_tag_path(record)
      assert_response :redirect
    end
  end

  test "deleting referenced category archives instead of breaking historical reports" do
    Finance::Tag.bootstrap!(@workspace.id)
    category = @workspace.finance_tags.find_by!(key: "office")
    tx = @workspace.finance_transactions.create!(
      kind: "expense", status: "draft", currency_code: "VND", entry_source: "manual",
      created_by_id: @user.id, transaction_date: Date.new(2026, 10, 29),
      description: "Paper", amount: 15000
    )
    Finance::TransactionTagging.apply!(transaction: tx, actor: @user,
      tag_ids: [category.id], new_names: "")
    Finance::ConfirmTransaction.call(transaction: tx, actor: @user, reviewed: true)
    assert_no_difference "Finance::Tag.count" do
      delete finance_tag_path(category)
      assert_response :redirect
    end
    assert_not category.reload.active?
    assert_equal ["office"], tx.reload.tags.pluck(:key)
    get new_finance_transaction_path(locale: "en")
    assert_select "input[name='transaction_tag_ids[]'][value='#{category.id}']", count: 0
    get finance_transaction_path(tx,locale:"vi")
    assert_response :success
    assert_includes response.body, "Văn phòng phẩm"
    get finance_reports_path(month:"2026-10",locale:"en")
    assert_response :success
    assert_includes response.body, "Office supplies"
    patch finance_tag_path(category), params:{finance_tag:{name_en:"Office & paper",name_vi:"Đồ dùng văn phòng",active:"1"}}
    assert_response :redirect
    assert category.reload.active?
    get new_finance_transaction_path(locale:"vi")
    assert_select "input[name='transaction_tag_ids[]'][value='#{category.id}'] + span", text: "Đồ dùng văn phòng"
  end

  test "new user-defined Tag is available for selection without changing the ledger" do
    Finance::Tag.bootstrap!(@workspace.id)
    tag = @workspace.finance_tags.create!(key: "legacy_custom", name_en: "Legacy custom",
      name_vi: "Tùy chỉnh", active: true)
    tx = @workspace.finance_transactions.create!(
      kind: "expense", status: "draft", currency_code: "VND", entry_source: "manual",
      created_by_id: @user.id, amount: 2000,
      transaction_date: Date.new(2026,10,22), description: "Example")
    Finance::TransactionTagging.apply!(transaction: tx, actor: @user,
      tag_ids: [tag.id], new_names: "")
    get finance_tags_path(locale: "vi")
    assert_response :success
    get edit_finance_tag_path(tag)
    assert_response :success
    get edit_finance_transaction_path(tx, locale: "en")
    assert_response :success
    assert_select "input[name='transaction_tag_ids[]'][value='#{tag.id}'][checked]"
  end

  test "other tenant cannot edit delete or see categories" do
    post finance_tags_path, params:{finance_tag:{key:"private_key",name_en:"Private expense",name_vi:"Danh mục riêng"}}
    category = @workspace.finance_tags.find_by!(key:"private_key")
    delete session_path
    post session_path, params:{email_address:@other.email_address,password:"ExampleSecure-2026!"}
    get finance_tags_path(locale:"en")
    assert_response :success
    assert_not_includes response.body, "Private expense"
    get edit_finance_tag_path(category)
    assert_response :not_found
    patch finance_tag_path(category),params:{finance_tag:{name_en:"Hacked"}}
    assert_response :not_found
    delete finance_tag_path(category)
    assert_response :not_found
    assert_equal "Private expense", category.reload.name_en
  end

  test "duplicate and invalid categories rejected; cannot mutate key" do
    Finance::Tag.bootstrap!(@workspace.id)
    assert_no_difference "Finance::Tag.count" do
      post finance_tags_path, params:{finance_tag:{key:"food",name_en:"Duplicate",name_vi:"Trùng"}}
      assert_response :unprocessable_entity
      post finance_tags_path, params:{finance_tag:{key:"bad key!",name_en:"Bad",name_vi:"Sai"}}
      assert_response :unprocessable_entity
    end
    c = @workspace.finance_tags.find_by!(key:"food")
    patch finance_tag_path(c),params:{finance_tag:{key:"hijack",name_en:"Food update",name_vi:"Cập nhật"}}
    assert_response :redirect
    assert_equal "food",c.reload.key
  end
end
