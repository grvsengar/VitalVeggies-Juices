class PagesController < ApplicationController
  def login
    @hide_site_chrome = true
  end

  def about; end

  def contact; end

  def faqs
    @faqs = Faq.ordered
  end

  def delivery
    @featured_promotion = Promotion.featured.first
  end

  def location
    @service_area = ServiceArea.find(params[:area])
    raise ActiveRecord::RecordNotFound if @service_area.blank?

    @featured_products = Product.featured.limit(4)
    @featured_promotion = Promotion.featured.first
    @articles = Article.featured.limit(2)
  end

  def privacy; end

  def terms; end
end
