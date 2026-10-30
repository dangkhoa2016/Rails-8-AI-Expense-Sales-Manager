# frozen_string_literal: true

class AddIndividualDatesTimesAndLocationsToFinanceLineItems < ActiveRecord::Migration[8.1]
  def change
    # Every line may have its own date, local time and free-text place;
    # absent values remain NULL (no inference from parent receipt or EXIF).
    add_column :finance_line_items, :occurred_on, :date
    add_column :finance_line_items, :occurred_time, :time
    add_column :finance_line_items, :location_text, :string, limit: 400
    add_check_constraint :finance_line_items,
      "location_text IS NULL OR char_length(btrim(location_text)) BETWEEN 1 AND 400",
      name: "finance_line_items_location_text_check"
  end
end
