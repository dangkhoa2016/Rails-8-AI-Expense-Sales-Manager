# frozen_string_literal: true

module Finance
  class CategoriesController < BaseController
    before_action :load_catalog!
    before_action :find_category!, only: %i[edit update destroy]

    def index
      @categories = category_scope.order(active: :desc, key: :asc)
      @category = category_scope.new(active: true)
    end

    def create
      @category = category_scope.new(category_params)
      @category.active = true
      if @category.save
        redirect_to finance_tags_path, notice: I18n.t("finance.categories.created"), status: :see_other
      else
        render_form_errors
      end
    end

    def edit
      @categories = category_scope.order(active: :desc, key: :asc)
      render :index
    end

    def update
      attrs = category_params.except(:key)
      if @category.update(attrs)
        redirect_to finance_tags_path, notice: I18n.t("finance.categories.updated"), status: :see_other
      else
        render_form_errors
      end
    end

    def destroy
      if @category.used?
        @category.update!(active: false)
        notice = I18n.t("finance.categories.archived")
      else
        @category.destroy!
        notice = I18n.t("finance.categories.deleted")
      end
      redirect_to finance_tags_path, notice: notice, status: :see_other
    end

    private

    def category_scope
      Finance::Category.for_workspace(@finance_workspace.id)
    end

    def load_catalog!
      Finance::Category.bootstrap!(@finance_workspace.id)
    end

    def find_category!
      @category = category_scope.find(params[:id])
    end

    def category_params
      params.require(:finance_category).permit(:key, :name_en, :name_vi, :active)
    end

    def render_form_errors
      @categories = category_scope.order(active: :desc, key: :asc)
      render :index, status: :unprocessable_entity
    end
  end
end
