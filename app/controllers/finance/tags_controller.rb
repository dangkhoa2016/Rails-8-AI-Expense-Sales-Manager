# frozen_string_literal: true

module Finance
  class TagsController < BaseController
    before_action :load_catalog!
    before_action :find_tag!, only: %i[edit update destroy]

    def index
      @tags = tag_scope.order(active: :desc, key: :asc)
      @tag = tag_scope.new(active: true)
    end

    def create
      @tag = tag_scope.new(tag_params)
      @tag.active = true
      if @tag.save
        redirect_to finance_tags_path, notice: I18n.t("finance.tags.created"), status: :see_other
      else
        render_form_errors
      end
    end

    def edit
      @tags = tag_scope.order(active: :desc, key: :asc)
      render :index
    end

    def update
      attrs = tag_params.except(:key)
      if @tag.update(attrs)
        redirect_to finance_tags_path, notice: I18n.t("finance.tags.updated"), status: :see_other
      else
        render_form_errors
      end
    end

    def destroy
      if @tag.used?
        @tag.update!(active: false)
        notice = I18n.t("finance.tags.archived")
      else
        @tag.destroy!
        notice = I18n.t("finance.tags.deleted")
      end
      redirect_to finance_tags_path, notice: notice, status: :see_other
    end

    private

    def tag_scope
      Finance::Tag.for_workspace(@finance_workspace.id)
    end

    def load_catalog!
      Finance::Tag.bootstrap!(@finance_workspace.id)
    end

    def find_tag!
      @tag = tag_scope.find(params[:id])
    end

    def tag_params
      params.require(:finance_tag).permit(:key, :name_en, :name_vi, :active)
    end

    def render_form_errors
      @tags = tag_scope.order(active: :desc, key: :asc)
      render :index, status: :unprocessable_entity
    end
  end
end
