require "test_helper"

class FinanceDateRangeFilterTest < ActiveSupport::TestCase
  def resolve(preset, date, reports: true, **extra)
    Finance::DateRangeFilter.for_params(
      ActionController::Parameters.new({preset: preset}.merge(extra)),
      default: "this_month", reports: reports, today: Date.iso8601(date))
  end

  test "two-week month templates use inclusive fourteen calendar days" do
    first = resolve("first_two_weeks_this_month", "2026-10-31")
    last = resolve("last_two_weeks_this_month", "2026-10-31")
    assert_equal Date.new(2026, 10, 1)..Date.new(2026, 10, 14), first.range
    assert_equal Date.new(2026, 10, 18)..Date.new(2026, 10, 31), last.range

    leap = resolve("last_two_weeks_this_month", "2028-02-10")
    assert_equal Date.new(2028, 2, 16)..Date.new(2028, 2, 29), leap.range
    regular = resolve("last_two_weeks_this_month", "2027-02-10")
    assert_equal Date.new(2027, 2, 15)..Date.new(2027, 2, 28), regular.range
  end

  test "week ranges start Monday and may cross month or year boundaries" do
    week = resolve("this_week", "2027-01-01")
    previous = resolve("previous_week", "2027-01-01")
    assert_equal Date.new(2026, 12, 28)..Date.new(2027, 1, 3), week.range
    assert_equal Date.new(2026, 12, 21)..Date.new(2026, 12, 27), previous.range
  end

  test "relative days, previous month and default all are deterministic" do
    assert_equal Date.new(2026, 10, 25)..Date.new(2026, 10, 31), resolve("last_7_days", "2026-10-31").range
    assert_equal Date.new(2026, 10, 2)..Date.new(2026, 10, 31), resolve("last_30_days", "2026-10-31").range
    assert_equal Date.new(2025, 12, 1)..Date.new(2025, 12, 31), resolve("previous_month", "2026-01-15").range
    all = resolve("all", "2026-10-31", reports: false)
    assert_nil all.range
    assert_equal({preset: "all"}, all.query_params)
  end

  test "custom dates, old month links and parameter serialization" do
    custom = resolve("custom", "2026-10-31", from: "2026-09-28", to: "2026-10-03")
    assert_equal Date.new(2026, 9, 28)..Date.new(2026, 10, 3), custom.range
    assert_equal({preset: "custom", from: "2026-09-28", to: "2026-10-03"}, custom.query_params)
    implicit = Finance::DateRangeFilter.for_params(ActionController::Parameters.new(from: "2026-10-01", to: "2026-10-02"), default: "this_month")
    assert_equal "custom", implicit.preset
    legacy = Finance::DateRangeFilter.for_params(ActionController::Parameters.new(month: "2026-10"), default: "this_month", reports: true)
    assert_equal Date.new(2026, 10, 1)..Date.new(2026, 10, 31), legacy.range
    assert_equal "custom", legacy.preset
  end

  test "reject invalid, missing or inverted ranges without raw SQL construction" do
    bad = [
      {preset: "custom", from: "2026-02-30", to: "2026-03-02"},
      {preset: "custom", from: "2026-10-02", to: "2026-10-01"},
      {preset: "custom", from: "2026-10-01"},
      {preset: "custom", from: "2026-10-01", to: "2026/10/31"},
      {preset: "nonsense"},
      {preset: "all"},
      {month: "2026-13"},
      {preset: "custom", from: "1899-01-01", to: "1900-01-01"},
      {preset: "custom", from: "2000-01-01", to: "2030-01-01"}
    ]
    bad.each do |params|
      assert_raises(ActionController::BadRequest, params.inspect) do
        Finance::DateRangeFilter.for_params(ActionController::Parameters.new(params),
          default: "this_month", reports: true, today: Date.new(2026, 10, 31))
      end
    end
  end
end
