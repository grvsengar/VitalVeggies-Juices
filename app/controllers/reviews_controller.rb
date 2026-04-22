class ReviewsController < ApplicationController
  def create
    product = Product.find(params[:product_id])
    review = product.reviews.new(review_params.merge(approved: false))

    if review.save
      redirect_to product_path(product.slug), notice: "Thanks for your feedback. Your review will appear after approval."
    else
      redirect_to product_path(product.slug), alert: review.errors.full_messages.to_sentence
    end
  end

  private

  def review_params
    params.require(:review).permit(:customer_name, :title, :body, :rating)
  end
end
