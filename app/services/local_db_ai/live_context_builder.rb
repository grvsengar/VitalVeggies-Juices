module LocalDbAi
  # Injects real-time store stats into the prompt so the model understands
  # the actual data shape and can give accurate summaries.
  class LiveContextBuilder
    def build
      lines = ["LIVE STORE SNAPSHOT (as of #{Date.today}):"]

      lines << order_stats
      lines << product_stats
      lines << date_range

      lines.compact.join("\n")
    rescue StandardError
      ""
    end

    private

    def order_stats
      total     = Order.count
      revenue   = Order.sum(:total).to_f.round(2)
      statuses  = Order.group(:status).count
                       .map { |s, c| "#{s}=#{c}" }.join(", ")
      recent    = Order.where("created_at >= ?", 7.days.ago).count
      avg       = Order.average(:total)&.round(2) || 0

      "- Orders: #{total} total (#{recent} last 7 days) | Revenue: ₹#{revenue} | Avg order: ₹#{avg} | Statuses: #{statuses}"
    end

    def product_stats
      total      = Product.count
      active     = Product.where(active: true).count
      low_stock  = Product.where("stock_quantity < 10").count
      out_stock  = Product.where("stock_quantity = 0").count
      kinds      = Product.group(:product_kind).count
                          .map { |k, c| "#{k}=#{c}" }.join(", ")

      "- Products: #{total} total (#{active} active, #{low_stock} low stock, #{out_stock} out of stock) | Kinds: #{kinds}"
    end

    def date_range
      oldest = Order.minimum(:created_at)&.to_date
      newest = Order.maximum(:created_at)&.to_date
      return nil unless oldest

      "- Order date range: #{oldest} to #{newest} (no orders exist outside this range)"
    end
  end
end
