# frozen_string_literal: true
require 'digest'
require 'stringio'
require 'vips'

module Finance
  class UploadDocument
    MAX_BYTES = 10.megabytes
    TYPES = %w[image/jpeg image/png image/webp].freeze

    def self.call(transaction:, upload:, actor:)
      raise ArgumentError, "Cancelled correction drafts are read-only" if transaction.cancelled?
      raise ArgumentError, 'Image is required' if upload.blank?
      raise ArgumentError, 'Image exceeds 10 MB' if upload.size.to_i <= 0 || upload.size.to_i > MAX_BYTES
      raise ArgumentError, 'Authenticated actor required' if actor.nil?

      source = upload.respond_to?(:tempfile) ? upload.tempfile : upload
      source.rewind
      bytes = source.read(MAX_BYTES + 1)
      raise ArgumentError, 'Image exceeds 10 MB' if bytes.bytesize > MAX_BYTES || bytes.empty?
      source.rewind
      filename = File.basename(upload.original_filename.to_s).slice(0, 180)
      filename = 'receipt-upload' if filename.blank?
      mime = Marcel::MimeType.for(StringIO.new(bytes), name: filename)
      raise ArgumentError, 'Unsupported or corrupt image' unless TYPES.include?(mime)
      # Generic decode check; no OCR, crop, enhancement, or inference heuristics.
      begin
        decoded = Vips::Image.new_from_buffer(bytes, '', access: :sequential)
        pixels = decoded.width * decoded.height
        raise ArgumentError, 'Image dimensions not supported' unless pixels.positive? && pixels <= 50_000_000
      rescue Vips::Error
        raise ArgumentError, 'Image contents cannot be decoded'
      end
      digest = Digest::SHA256.hexdigest(bytes)
      blob = ActiveStorage::Blob.create_and_upload!(
        io: StringIO.new(bytes), filename: filename, content_type: mime, identify: false
      )
      begin
        record = nil
        Finance::Transaction.transaction do
          transaction.lock!
          last = transaction.document_versions.order(version_number: :desc).first
          record = transaction.document_versions.create!(
            version_number: (last&.version_number || 0) + 1,
            sha256: digest, original_filename: filename,
            content_type: mime, byte_size: bytes.bytesize,
            uploaded_by_id: actor.id, supersedes_version_id: last&.id
          )
          # Direct attachment row avoids saving immutable version record a second time.
          ActiveStorage::Attachment.create!(name: 'image', record: record, blob: blob)
          # Confirmed financial records are immutable. New uploads remain separate
          # supplemental evidence; the confirmed active snapshot never changes.
          transaction.update!(active_document_version: record) if transaction.draft?
          Finance::AuditEvent.create!(finance_transaction: transaction, workspace_id: transaction.workspace_id,
            actor_id: actor.id, event_type: transaction.draft? ? 'document_version_added' : 'supplemental_evidence_added',
            payload: { version_id: record.id, number: record.version_number,
                       sha256: digest, bytes: bytes.bytesize })
        end
        record
      rescue StandardError
        blob.purge if blob && !blob.attachments.exists?
        raise
      end
    end
  end
end
