module Manager
  class SearchController < BaseController
    def show
      @query = params[:q].to_s.strip
      @nav_results = navigation_results(@query)

      if @query.present?
        @orders = Order.where("order_number ILIKE :q OR customer_name ILIKE :q OR phone ILIKE :q", q: "%#{@query}%")
                       .recent_first
                       .limit(5)

        @products = Product.includes(:category)
                           .where("name ILIKE :q OR sku ILIKE :q", q: "%#{@query}%")
                           .order(:name)
                           .limit(5)
      else
        @orders = []
        @products = []
      end

      respond_to do |format|
        format.html { render layout: false }
      end
    end

    private

    def navigation_results(query)
      items = [
        { name: "Dashboard", url: manager_dashboard_path, icon: "dashboard", hint: "Overview and live analytics" },
        { name: "Products", url: manager_products_path, icon: "products", hint: "Review the storefront catalog" },
        { name: "Inventory", url: manager_inventory_index_path, icon: "inventory", hint: "Update stock and availability" },
        { name: "Orders", url: manager_orders_path, icon: "orders", hint: "Track incoming orders" },
        { name: "Marketing Studio", url: manager_marketing_studio_path, icon: "studio", hint: "Generate campaign assets" }
      ]

      return items if query.blank?

      items.select do |item|
        [item[:name], item[:hint]].compact.any? { |value| value.downcase.include?(query.downcase) }
      end
    end
  end
end
