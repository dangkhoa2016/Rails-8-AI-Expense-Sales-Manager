# frozen_string_literal: true
require "csv"
require "digest"

module Finance
  # Manual CSV import only. Never extracts characters/numbers from an image,
  # never infers totals and never writes to an already confirmed ledger.
  class ImportLineItems
    MAX_BYTES = 512 * 1024
    MAX_ITEMS = 500
    HEADERS = %w[description amount quantity unit_price category occurred_on occurred_time location_text].freeze
    REQUIRED = %w[description amount].freeze

    def self.call(transaction:, actor:, upload:)
      raise ArgumentError, "Select a CSV file" unless upload.respond_to?(:read)
      bytes = upload.read(MAX_BYTES + 1)
      raise ArgumentError, "CSV file must be at most 512 KiB" if bytes.bytesize > MAX_BYTES
      raise ArgumentError, "CSV file is empty" if bytes.empty?

      content = bytes.dup.force_encoding(Encoding::UTF_8).delete_prefix("\uFEFF")
      raise ArgumentError, "CSV must be UTF-8" unless content.valid_encoding?
      table = CSV.parse(content, headers: true, liberal_parsing: false)
      columns = table.headers
      unless columns && columns.uniq == columns && (columns - HEADERS).empty? &&
             (REQUIRED - columns).empty?
        raise ArgumentError, "CSV requires description,amount; optional quantity,unit_price,category,occurred_time,location_text (legacy occurred_on accepted only if it matches transaction date)"
      end
      raise ArgumentError, "CSV must contain between 1 and 500 rows" unless table.size.between?(1, MAX_ITEMS)

      rows = table.each_with_index.map do |row, i|
        raise ArgumentError, "Malformed row #{i + 2}" unless row.is_a?(CSV::Row)
        description = row["description"].to_s.strip
        raise ArgumentError, "Invalid description on row #{i + 2}" if description.empty? || description.length > 500
        category = row["category"]&.strip.presence
        raise ArgumentError, "Category too long on row #{i + 2}" if category&.length.to_i > 100
        location = row["location_text"]&.strip.presence
        raise ArgumentError, "Location too long on row #{i + 2}" if location&.length.to_i > 400
        {
          description: description,
          amount: decimal(row["amount"], scale: 2, min: 0, row: i + 2, name: "amount"),
          quantity: decimal(row["quantity"], scale: 3, min: 0, row: i + 2, name: "quantity", optional: true, strictly_positive: true),
          unit_price: decimal(row["unit_price"], scale: 2, min: 0, row: i + 2, name: "unit_price", optional: true),
          category: category,
          legacy_occurred_on: row["occurred_on"]&.strip,
          occurred_time: optional_time(row["occurred_time"], row: i + 2),
          location_text: location,
          entry_source: "manual"
        }
      end

      sha = Digest::SHA256.hexdigest(bytes)
      result = nil
      Finance::Transaction.transaction do
        tx = Finance::Transaction.lock.find(transaction.id)
        raise ArgumentError, "Only drafts accept line items" unless tx.draft?
        raise ArgumentError, "Cannot import into another workspace" unless actor && tx.workspace_id == transaction.workspace_id
        if tx.line_import_batches.exists?(sha256: sha)
          result = :already_imported
        else
          current = tx.line_items.count
          raise ArgumentError, "Maximum 500 line items per transaction" if current + rows.size > MAX_ITEMS
          position = tx.line_items.maximum(:position).to_i
          position = -1 if current == 0
          rows.each_with_index do |attrs, idx|
            # Older CSV files may still carry occurred_on. Validate rather than
            # silently discarding conflicting dates; never persist item dates.
            validate_legacy_date!(attrs[:legacy_occurred_on], tx.transaction_date, row: idx + 2)
            tx.line_items.create!(attrs.except(:legacy_occurred_on).merge(position: position + idx + 1))
          end
          Finance::SyncDraftLineTotal.call(transaction: tx, actor: actor, reason: "csv_import")
          tx.line_import_batches.create!(sha256: sha, row_count: rows.size, uploaded_by_id: actor.id)
          Finance::AuditEvent.create!(
            finance_transaction: tx, workspace_id: tx.workspace_id, actor_id: actor.id,
            event_type: "finance_line_items_csv_imported",
            payload: { sha256: sha, row_count: rows.size, import_type: "manual_csv", total_lines_after: current + rows.size }
          )
          result = :imported
        end
      end
      { status: result, rows: rows.size, sha256: sha }
    rescue CSV::MalformedCSVError
      raise ArgumentError, "Invalid CSV formatting"
    end

    def self.validate_legacy_date!(value, transaction_date, row:)
      return if value.blank?
      unless value.match?(/\A\d{4}-\d{2}-\d{2}\z/)
        raise ArgumentError, "Invalid legacy item date on row #{row}; use YYYY-MM-DD"
      end
      parsed = Date.iso8601(value)
      unless parsed == transaction_date
        raise ArgumentError, "Legacy item date on row #{row} differs from the transaction date; update the transaction date or remove occurred_on from the CSV"
      end
    rescue Date::Error
      raise ArgumentError, "Invalid legacy item date on row #{row}; use YYYY-MM-DD"
    end

    def self.optional_time(value, row:)
      str = value.to_s.strip
      return nil if str.empty?
      unless str.match?(/\A(?:[01]\d|2[0-3]):[0-5]\d\z/)
        raise ArgumentError, "Invalid item time on row #{row}; use 24h HH:MM"
      end
      str
    end
    private_class_method :validate_legacy_date!, :optional_time

    def self.decimal(value, scale:, min:, row:, name:, optional: false, strictly_positive: false)
      string = value.to_s.strip
      return nil if optional && string.empty?
      pattern = scale == 3 ? /\A\d+(?:\.\d{1,3})?\z/ : /\A\d+(?:\.\d{1,2})?\z/
      raise ArgumentError, "Invalid #{name} on row #{row}" unless string.match?(pattern) && string.length <= 22
      number = BigDecimal(string)
      if number < min || (strictly_positive && !number.positive?)
        raise ArgumentError, "Invalid #{name} on row #{row}"
      end
      number
    end
    private_class_method :decimal
  end
end
