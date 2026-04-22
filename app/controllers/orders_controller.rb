class OrdersController < ApplicationController
  before_action :require_buyer!, only: %i[new create]
  before_action :ensure_cart_has_items, only: %i[new create]

  def new
    @order = Order.new(payment_method: "cash_on_delivery")
    @promotion = current_promotion
    @addresses = current_user.addresses if buyer_signed_in?
  end

  def create
    @promotion = current_promotion
    @order = Order.new(order_params)
    @addresses = current_user.addresses if buyer_signed_in?

    if buyer_signed_in?
      @order.user = current_user
      if params[:address_id].present?
        address = current_user.addresses.find_by(id: params[:address_id])
        if address
          @order.address = address
          @order.assign_attributes(
            customer_name: address.recipient_name,
            phone: address.phone,
            address_line1: address.address_line1,
            address_line2: address.address_line2,
            city: address.city,
            state: address.state,
            postal_code: address.postal_code
          )
        end
      end
    end

    assign_order_totals(@order, @promotion)

    if current_cart.stock_issue_items.any?
      @order.errors.add(:base, "Some cart quantities exceed available stock. Please update your cart.")
      render :new, status: :unprocessable_entity
      return
    end

    Order.transaction do
      locked_lines = lock_cart_lines
      build_order_items(@order, locked_lines)
      reserve_inventory!(locked_lines)
      @order.save!

      if buyer_signed_in? && @order.address.nil?
        # Save new address for future use
        new_address = current_user.addresses.create!(
          recipient_name: @order.customer_name,
          phone: @order.phone,
          address_line1: @order.address_line1,
          address_line2: @order.address_line2,
          city: @order.city,
          state: @order.state,
          postal_code: @order.postal_code,
          name: "Saved Address #{current_user.addresses.count + 1}"
        )
        @order.update!(address: new_address)
      end

      decrement_inventory!(locked_lines)
    end

    current_cart.clear
    session.delete(:coupon_code)
    redirect_to @order, notice: "Order placed successfully."
  rescue ActiveRecord::RecordInvalid
    render :new, status: :unprocessable_entity
  end

  def show
    @order = Order.includes(order_items: :product).find(params[:id])
  end

  def tracking_form; end

  def track
    @order = Order.find_by("LOWER(order_number) = ? AND LOWER(email) = ?", params[:order_number].to_s.downcase, params[:email].to_s.downcase)

    if @order
      redirect_to @order
    else
      flash.now[:alert] = "We could not find that order. Please check the order number and email."
      render :tracking_form, status: :unprocessable_entity
    end
  end

  private

  def order_params
    params.require(:order).permit(
      :customer_name, :email, :phone, :address_line1, :address_line2,
      :city, :state, :postal_code, :notes, :payment_method, :delivery_window
    )
  end

  def assign_order_totals(order, promotion)
    subtotal = current_cart.subtotal
    discount_total = current_cart.discount_for(promotion)
    delivery_fee = current_cart.delivery_fee

    order.assign_attributes(
      coupon_code: promotion&.promo_code,
      payment_status: "pending",
      subtotal:,
      discount_total:,
      delivery_fee:,
      total: subtotal - discount_total + delivery_fee
    )
  end

  def build_order_items(order, lines)
    lines.each do |line|
      order.order_items.build(
        product: line[:product],
        product_name: line[:product].name,
        quantity: line[:quantity],
        unit_price: line[:product].price,
        line_total: line[:product].price * line[:quantity]
      )
    end
  end

  def lock_cart_lines
    current_cart.items.map do |item|
      {
        product: Product.lock.find(item.product.id),
        quantity: item.quantity
      }
    end
  end

  def reserve_inventory!(lines)
    lines.each do |line|
      next if line[:product].stock_quantity >= line[:quantity]

      @order.errors.add(:base, "#{line[:product].name} has only #{line[:product].stock_quantity} left.")
      raise ActiveRecord::RecordInvalid, @order
    end
  end

  def decrement_inventory!(lines)
    lines.each do |line|
      line[:product].update!(stock_quantity: line[:product].stock_quantity - line[:quantity])
    end
  end

  def ensure_cart_has_items
    redirect_to products_path, alert: "Your cart is empty." if current_cart.count.zero?
  end
end
