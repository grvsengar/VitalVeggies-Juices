class OrdersController < ApplicationController
  before_action :require_buyer!, only: %i[new create]
  before_action :ensure_cart_has_items, only: %i[new create]
  skip_forgery_protection only: %i[payment_callback payment_webhook]

  def new
    @order = Order.new(payment_method: "cash_on_delivery")
    @promotion = current_promotion
    @addresses = current_user.addresses if buyer_signed_in?
  end

  def create
    return create_online_gateway_order if online_gateway_selected?

    create_offline_order
  end

  def payment
    @order = Order.includes(order_items: :product).find(params[:id])

    if !@order.online_gateway?
      redirect_to @order, alert: "This order does not require online payment."
      return
    end

    if @order.paid?
      redirect_to @order, notice: "Payment has already been completed for this order."
      return
    end

    if @order.gateway_order_id.blank?
      redirect_to @order, alert: "Payment session is unavailable for this order."
      return
    end

    unless RazorpayClient.configured?
      redirect_to @order, alert: "Online payments are not configured yet."
      return
    end

    @razorpay_key_id = ENV["RAZORPAY_KEY_ID"]
  end

  def payment_callback
    order = Order.includes(order_items: :product).find_by!(gateway_order_id: params[:razorpay_order_id])

    unless razorpay_client.valid_signature?(
      order_id: order.gateway_order_id,
      payment_id: params[:razorpay_payment_id],
      signature: params[:razorpay_signature]
    )
      order.update(
        payment_status: "failed",
        gateway_payment_id: params[:razorpay_payment_id],
        gateway_signature: params[:razorpay_signature],
        payment_provider: "razorpay"
      )

      redirect_to payment_order_path(order), alert: "Payment verification failed. Please try again."
      return
    end

    payment = razorpay_client.fetch_payment(params[:razorpay_payment_id])
    payment = capture_authorized_payment(order, payment)

    Order.transaction do
      order.lock!
      finalize_online_order!(order) unless order.paid?

      order.update!(
        payment_status: payment_captured?(payment) ? "paid" : "pending",
        status: payment_captured?(payment) ? "confirmed" : order.status,
        payment_provider: "razorpay",
        gateway_payment_id: params[:razorpay_payment_id],
        gateway_signature: params[:razorpay_signature],
        gateway_payment_method: payment["method"],
        paid_at: payment_captured?(payment) ? Time.current : order.paid_at
      )
    end

    current_cart.clear
    session.delete(:coupon_code)
    redirect_to order, notice: "Payment received successfully."
  rescue ActiveRecord::RecordInvalid => error
    if order&.persisted?
      order.update(
        payment_status: "paid",
        status: order.status,
        payment_provider: "razorpay",
        gateway_payment_id: params[:razorpay_payment_id],
        gateway_signature: params[:razorpay_signature],
        paid_at: Time.current,
        notes: append_system_note(order.notes, error.record.errors.full_messages.to_sentence.presence || error.message)
      )
      redirect_to order, alert: "Payment was received, but inventory changed before confirmation. Please review this order manually."
    else
      redirect_to new_order_path, alert: "Payment was received, but the order could not be finalized."
    end
  rescue RazorpayClient::Error => error
    redirect_to payment_order_path(order), alert: error.message
  end

  def payment_webhook
    raw_payload = request.raw_post
    signature = request.headers["X-Razorpay-Signature"]

    unless RazorpayClient.valid_webhook_signature?(payload: raw_payload, signature:)
      head :unauthorized
      return
    end

    payload = JSON.parse(raw_payload)
    payment_entity = payload.dig("payload", "payment", "entity")
    order = Order.includes(order_items: :product).find_by(gateway_order_id: payment_entity&.dig("order_id"))

    unless order
      head :ok
      return
    end

    case payload["event"]
    when "payment.captured", "order.paid"
      Order.transaction do
        order.lock!
        finalize_online_order!(order) unless order.paid?

        order.update!(
          payment_status: "paid",
          status: "confirmed",
          payment_provider: "razorpay",
          gateway_payment_id: payment_entity&.dig("id") || order.gateway_payment_id,
          gateway_payment_method: payment_entity&.dig("method") || order.gateway_payment_method,
          paid_at: order.paid_at || Time.current
        )
      end
    when "payment.failed"
      order.update!(
        payment_status: "failed",
        payment_provider: "razorpay",
        gateway_payment_id: payment_entity&.dig("id") || order.gateway_payment_id,
        gateway_payment_method: payment_entity&.dig("method") || order.gateway_payment_method
      )
    end

    head :ok
  rescue JSON::ParserError
    head :unprocessable_entity
  rescue ActiveRecord::RecordInvalid => error
    order&.update(
      payment_status: "paid",
      payment_provider: "razorpay",
      gateway_payment_id: payment_entity&.dig("id") || order&.gateway_payment_id,
      gateway_payment_method: payment_entity&.dig("method") || order&.gateway_payment_method,
      paid_at: order&.paid_at || Time.current,
      notes: append_system_note(order&.notes, error.record.errors.full_messages.to_sentence.presence || error.message)
    )
    head :ok
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

  def create_offline_order
    @promotion = current_promotion
    @order = Order.new(order_params)
    @addresses = current_user.addresses if buyer_signed_in?

    hydrate_order_from_current_user!(@order)
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

      persist_new_address!(@order)
      decrement_inventory!(locked_lines)
    end

    current_cart.clear
    session.delete(:coupon_code)
    redirect_to @order, notice: "Order placed successfully."
  rescue ActiveRecord::RecordInvalid
    render :new, status: :unprocessable_entity
  end

  def create_online_gateway_order
    @promotion = current_promotion
    @order = Order.new(order_params)
    @addresses = current_user.addresses if buyer_signed_in?

    unless RazorpayClient.configured?
      @order.errors.add(:base, "Online payments are not configured. Add RAZORPAY_KEY_ID and RAZORPAY_KEY_SECRET.")
      render :new, status: :unprocessable_entity
      return
    end

    hydrate_order_from_current_user!(@order)
    assign_order_totals(@order, @promotion)
    @order.payment_provider = "razorpay"

    if current_cart.stock_issue_items.any?
      @order.errors.add(:base, "Some cart quantities exceed available stock. Please update your cart.")
      render :new, status: :unprocessable_entity
      return
    end

    Order.transaction do
      locked_lines = lock_cart_lines
      reserve_inventory!(locked_lines)
      build_order_items(@order, locked_lines)
      @order.save!
    end

    gateway_order = razorpay_client.create_order(
      amount: @order.total_in_subunits,
      receipt: @order.order_number,
      notes: {
        local_order_id: @order.id.to_s,
        order_number: @order.order_number
      }
    )

    @order.update!(gateway_order_id: gateway_order.fetch("id"))
    persist_new_address!(@order)
    redirect_to payment_order_path(@order)
  rescue ActiveRecord::RecordInvalid, RazorpayClient::Error => error
    @order.destroy if @order&.persisted? && @order.gateway_order_id.blank? && !@order.paid?
    @order.errors.add(:base, error.message)
    render :new, status: :unprocessable_entity
  end

  def order_params
    params.require(:order).permit(
      :customer_name, :email, :phone, :address_line1, :address_line2,
      :city, :state, :postal_code, :notes, :payment_method, :delivery_window
    )
  end

  def online_gateway_selected?
    params.dig(:order, :payment_method) == Order::ONLINE_PAYMENT_METHOD
  end

  def hydrate_order_from_current_user!(order)
    return unless buyer_signed_in?

    order.user = current_user
    order.email = current_user.email if order.email.blank?
    return if params[:address_id].blank?

    address = current_user.addresses.find_by(id: params[:address_id])
    return unless address

    order.address = address
    order.assign_attributes(
      customer_name: address.recipient_name,
      phone: address.phone,
      address_line1: address.address_line1,
      address_line2: address.address_line2,
      city: address.city,
      state: address.state,
      postal_code: address.postal_code
    )
  end

  def persist_new_address!(order)
    return unless buyer_signed_in? && order.address.nil?

    new_address = current_user.addresses.create!(
      recipient_name: order.customer_name,
      phone: order.phone,
      address_line1: order.address_line1,
      address_line2: order.address_line2,
      city: order.city,
      state: order.state,
      postal_code: order.postal_code,
      name: "Saved Address #{current_user.addresses.count + 1}"
    )
    order.update!(address: new_address)
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

  def finalize_online_order!(order)
    locked_lines = order.order_items.includes(:product).map do |item|
      {
        item:,
        product: Product.lock.find(item.product_id)
      }
    end

    locked_lines.each do |line|
      next if line[:product].stock_quantity >= line[:item].quantity

      order.errors.add(:base, "#{line[:product].name} has only #{line[:product].stock_quantity} left.")
      raise ActiveRecord::RecordInvalid, order
    end

    locked_lines.each do |line|
      line[:product].update!(stock_quantity: line[:product].stock_quantity - line[:item].quantity)
    end
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

  def capture_authorized_payment(order, payment)
    return payment unless payment["status"] == "authorized" && payment["captured"] != true

    razorpay_client.capture_payment(
      payment["id"],
      amount: order.total_in_subunits,
      currency: "INR"
    )
  end

  def payment_captured?(payment)
    payment["status"] == "captured" || payment["captured"] == true
  end

  def append_system_note(existing_notes, message)
    [existing_notes.presence, "[System] #{message}"].compact.join("\n\n")
  end

  def razorpay_client
    @razorpay_client ||= RazorpayClient.new
  end

  def ensure_cart_has_items
    redirect_to products_path, alert: "Your cart is empty." if current_cart.count.zero?
  end
end
