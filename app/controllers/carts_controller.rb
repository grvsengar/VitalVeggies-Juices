class CartsController < ApplicationController
  def show
    @promotion = current_promotion
    @stock_issues = current_cart.stock_issue_items
  end

  def create
    product = Product.active.find(params[:product_id])
    requested_quantity = [params.fetch(:quantity, 1).to_i, 1].max
    current_quantity = current_cart.quantity_for(product.id)

    if product.stock_quantity <= current_quantity
      flash.now[:alert] = "#{product.name} is fully allocated in your cart already."
      respond_to do |format|
        format.turbo_stream { render :create }
        format.html { redirect_back fallback_location: cart_path, alert: flash.now[:alert] }
      end
      return
    end

    quantity_to_add = [requested_quantity, product.stock_quantity - current_quantity].min
    current_cart.add(product.id, quantity_to_add)

    message = if quantity_to_add < requested_quantity
      "Only #{quantity_to_add} more #{product.name} added because of current stock."
    else
      "#{product.name} added to your cart."
    end

    flash.now[:notice] = message

    respond_to do |format|
      format.turbo_stream
      format.html { redirect_back fallback_location: cart_path, notice: message }
    end
  end

  def update
    product = Product.active.find(params[:product_id])
    requested_quantity = params[:quantity].to_i

    if requested_quantity > product.stock_quantity
      current_cart.update(product.id, product.stock_quantity)
      redirect_to cart_path, alert: "#{product.name} quantity was adjusted to available stock."
    else
      current_cart.update(product.id, requested_quantity)
      redirect_to cart_path, notice: "Cart updated."
    end
  end

  def destroy
    current_cart.remove(params[:product_id])
    redirect_to cart_path, notice: "Item removed from your cart."
  end

  def apply_coupon
    code = params[:promo_code].to_s.upcase.strip
    promotion = Promotion.current.find_by(promo_code: code)

    if promotion
      session[:coupon_code] = promotion.promo_code
      redirect_to cart_path, notice: "Coupon applied successfully."
    else
      session.delete(:coupon_code)
      redirect_to cart_path, alert: "Coupon code not found or expired."
    end
  end
end
