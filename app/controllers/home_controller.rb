class HomeController < ApplicationController
  def index
    @categories = Category.active.ordered
    @featured_products = Product.featured.limit(8)
    @seasonal_products = Product.active.where(seasonal: true).ordered.limit(4)
    @featured_promotions = Promotion.featured.limit(2)
    @testimonials = Testimonial.featured.limit(3)
    @articles = Article.featured.limit(3)
    @faqs = Faq.ordered.limit(4)
  end
end
