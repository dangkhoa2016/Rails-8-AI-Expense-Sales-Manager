# frozen_string_literal: true
module Finance
  class DocumentVersionsController < BaseController
    before_action :load_finance_transaction!
    before_action :load_version!, only: %i[show image]

    def create
      image = params.require(:document_version).require(:image)
      version = Finance::UploadDocument.call(transaction: @transaction, upload: image,
                                             actor: @finance_actor)
      redirect_to finance_transaction_document_version_path(@transaction, version),
                  notice: 'New image version saved; the original versions remain available.'
    rescue ActionController::ParameterMissing, ArgumentError, ActiveRecord::RecordInvalid => e
      redirect_to finance_transaction_path(@transaction), alert: e.message
    end

    def show
      @extractions = @version.extraction_runs.order(created_at: :desc)
    end

    def image
      raise ActionController::RoutingError, 'Not Found' unless @version.image.attached?
      response.headers['Cache-Control'] = 'private, no-store'
      response.headers['X-Content-Type-Options'] = 'nosniff'
      send_data @version.image.download, type: @version.content_type,
                disposition: 'inline', filename: @version.original_filename
    end

    private

    def load_version!
      @version = @transaction.document_versions.find(params[:id])
    end
  end
end
