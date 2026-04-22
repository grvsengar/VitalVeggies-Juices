class Cart
  Item = Struct.new(:product, :quantity, keyword_init: true) do
    def total_price
      product.price * quantity
    end
  end

  DELIVERY_THRESHOLD = 500
  STANDARD_DELIVERY_FEE = BigDecimal("50")

  def initialize(session)
    @session = session
    @session[:cart] ||= {}
  end

  def items
    products_by_id.map do |product_id, product|
      Item.new(product:, quantity: line_items[product_id].to_i)
    end
  end

  def add(product_id, quantity = 1)
    key = product_id.to_s
    line_items[key] = line_items.fetch(key, 0).to_i + quantity.to_i
  end

  def update(product_id, quantity)
    key = product_id.to_s

    if quantity.to_i <= 0
      line_items.delete(key)
    else
      line_items[key] = quantity.to_i
    end
  end

  def remove(product_id)
    line_items.delete(product_id.to_s)
  end

  def count
    line_items.values.sum(&:to_i)
  end

  def quantity_for(product_id)
    line_items[product_id.to_s].to_i
  end

  def subtotal
    items.sum(&:total_price)
  end

  def delivery_fee
    subtotal >= DELIVERY_THRESHOLD || count.zero? ? 0 : STANDARD_DELIVERY_FEE
  end

  def discount_for(promotion)
    return 0.to_d unless promotion&.active_now?

    promotion.discount_for(subtotal)
  end

  def clear
    line_items.clear
  end

  def stock_issue_items
    items.filter_map do |item|
      next if item.product.stock_quantity >= item.quantity

      {
        item:,
        available_quantity: item.product.stock_quantity
      }
    end
  end

  def valid_for_checkout?
    stock_issue_items.empty?
  end

  private

  def line_items
    @session[:cart]
  end

  def products_by_id
    ids = line_items.keys.map(&:to_i)
    Product.where(id: ids).index_by(&:id).stringify_keys
  end
end
