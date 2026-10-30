# frozen_string_literal: true
require 'minitest/autorun'
require 'bigdecimal'
require 'date'
require_relative '../app/services/finance/input_policy'

class InputPolicyTest < Minitest::Test
  def test_unreadable_is_not_file_corruption
    assert_equal :manual_entry_or_better_image, Finance::InputPolicy.ui_mode('unreadable')
    assert_equal :upload_supported_file_or_manual, Finance::InputPolicy.ui_mode('invalid_file')
  end

  def test_http_errors_are_not_unreadable_receipts
    assert_equal :retry_or_manual, Finance::InputPolicy.ui_mode('processing_error')
  end

  def test_partially_readable_keeps_manual_path
    assert_equal :review_ai_fields_or_manual, Finance::InputPolicy.ui_mode('partially_readable')
    assert_equal :review_ai_fields_or_manual, Finance::InputPolicy.ui_mode('readable')
  end

  def test_ai_never_posts_financial_data
    refute Finance::InputPolicy.auto_post_from_ai?
    refute Finance::InputPolicy.reportable?(status: 'draft')
    assert Finance::InputPolicy.reportable?(status: 'confirmed')
  end

  def test_no_confirmation_without_date
    refute Finance::InputPolicy.confirmable?(date: nil, amount: BigDecimal('43500'), actor_id: 1,
                                              human_confirmed: true)
  end

  def test_no_confirmation_without_human_review
    refute Finance::InputPolicy.confirmable?(date: Date.new(2026, 10, 27), amount: BigDecimal('43500'),
                                              actor_id: 1, human_confirmed: false)
  end

  def test_no_confirmation_without_valid_amount
    refute Finance::InputPolicy.confirmable?(date: Date.new(2026, 10, 27), amount: BigDecimal('0'),
                                              actor_id: 1, human_confirmed: true)
    refute Finance::InputPolicy.confirmable?(date: Date.new(2026, 10, 27), amount: nil,
                                              actor_id: 1, human_confirmed: true)
  end

  def test_no_confirmation_without_identity
    refute Finance::InputPolicy.confirmable?(date: Date.new(2026, 10, 27), amount: BigDecimal('43500'),
                                              actor_id: nil, human_confirmed: true)
  end

  def test_manual_confirmation_is_permitted
    assert Finance::InputPolicy.confirmable?(date: Date.new(2026, 10, 27), amount: BigDecimal('43500'),
                                              actor_id: 7, human_confirmed: true)
  end

  def test_unknown_status_fails_closed
    assert_equal :unknown_status, Finance::InputPolicy.ui_mode('AUTHENTICATED_401')
  end
end
