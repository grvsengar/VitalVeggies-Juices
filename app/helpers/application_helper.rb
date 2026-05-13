module ApplicationHelper
  VEG_IMAGE_LIBRARY = {
    home_hero: "veg-img/altesc-frame-R_n3WU2sh70-unsplash.jpg",
    home_feature: "veg-img/sharon-pittaway-KUZnfk-2DSQ-unsplash.jpg",
    article_feature: "veg-img/altesc-frame-R_n3WU2sh70-unsplash.jpg",
    article_cards: [
      "veg-img/harshal-s-hirve-2GiRcLP_jkI-unsplash.jpg",
      "veg-img/angelique-AXyvGt8UH14-unsplash.jpg",
      "veg-img/heather-barnes-vkpR5r4rk-w-unsplash.jpg",
      "veg-img/sharon-pittaway-KUZnfk-2DSQ-unsplash.jpg"
    ]
  }.freeze

  BUSINESS_DETAILS = {
    name: "Vital Veggies & Juices",
    phone: "+91 98765 43210",
    email: "hello@vitalveggies.in",
    address: "24 Market Road, Indiranagar, Bengaluru, Karnataka 560038",
    hours: "Mon-Sat 7:00 AM - 9:00 PM, Sun 8:00 AM - 3:00 PM",
    social_links: {
      instagram: "https://instagram.com/vitalveggiesjuices",
      facebook: "https://facebook.com/vitalveggiesjuices"
    }
  }.freeze

  def business_details
    BUSINESS_DETAILS
  end

  def service_areas
    ServiceArea.all
  end

  def page_title(title = nil)
    [ title, business_details[:name] ].compact.join(" | ")
  end

  def page_description(description = nil)
    description.presence || "Fresh juices, Indian fruits, farm vegetables, local delivery, and healthy weekly produce subscriptions."
  end

  def product_transition_name(product)
    "product-media-#{product.id}"
  end

  def nav_link_to(label, path, options = {})
    classes = [ "site-nav__link", ("site-nav__link--active" if current_page?(path)), options[:class] ].compact.join(" ")
    link_to label, path, options.merge(class: classes)
  end

  def money(amount)
    number_to_currency(amount || 0, unit: "₹", precision: 0)
  end

  def stars_for(rating)
    "★" * rating.to_i
  end

  def product_image_path(product)
    return product.image.url if product.respond_to?(:image) && product.image.present?

    image_name = case product.slug
                 when /leafy|greens|sabzi/
                   "veg-img/heather-barnes-vkpR5r4rk-w-unsplash.jpg"
                 when /kitchen|veggie|crate/
                   "veg-img/sharon-pittaway-KUZnfk-2DSQ-unsplash.jpg"
                 when /detox/
                   "veg-img/altesc-frame-R_n3WU2sh70-unsplash.jpg"
                 when /family.*combo|combo.*family|family-fresh/
                   "veg-img/sharon-pittaway-KUZnfk-2DSQ-unsplash.jpg"
                 when /alphonso-mango/
                   "veg-img/alphonso-mango.png"
                 when /mango|tropical/
                   "product-mango-basket.svg"
                 when /banana|snack/
                   "product-banana-guava.svg"
                 when /citrus|mosambi/
                   "product-citrus-juice.svg"
                 when /berry/
                   "product-mixed-fruit.svg"
                 else
                   case product.product_kind
                   when "vegetable"
                     "veg-img/sharon-pittaway-KUZnfk-2DSQ-unsplash.jpg"
                   when "combo"
                     "veg-img/altesc-frame-R_n3WU2sh70-unsplash.jpg"
                   else
                     "product-mixed-fruit.svg"
                   end
                 end

    resolve_image_path(image_name)
  end

  def category_image_path(category)
    image_name = case category.slug
                 when /juice/
                   "category-juice.svg"
                 when /fruit/
                   "category-fruit.svg"
                 when /vegetable/
                   "veg-img/sharon-pittaway-KUZnfk-2DSQ-unsplash.jpg"
                 when /family|combo/
                   "veg-img/altesc-frame-R_n3WU2sh70-unsplash.jpg"
                 else
                   "category-combo.svg"
                 end

    resolve_image_path(image_name)
  end

  def article_image_path(article, index: 0, featured: false)
    return article.image.url if article.image?
    return resolve_image_path(VEG_IMAGE_LIBRARY[:article_feature]) if featured

    image_name = case article.slug
                 when /subscription|weekly|box/
                   "veg-img/altesc-frame-R_n3WU2sh70-unsplash.jpg"
                 when /summer|recipes/
                   "veg-img/angelique-AXyvGt8UH14-unsplash.jpg"
                 when /morning|juice|fresh/
                   "veg-img/harshal-s-hirve-2GiRcLP_jkI-unsplash.jpg"
                 else
                   VEG_IMAGE_LIBRARY[:article_cards][index % VEG_IMAGE_LIBRARY[:article_cards].length]
                 end

    resolve_image_path(image_name)
  end

  def site_image_path(key)
    resolve_image_path(VEG_IMAGE_LIBRARY.fetch(key))
  end

  def stock_badge(product)
    return "Unavailable" unless product.active?
    return "Sold out" unless product.in_stock?
    return "Low stock" if product.low_stock?

    "In stock"
  end

  def stock_badge_class(product)
    return "inventory-pill inventory-pill--danger" unless product.active? && product.in_stock?
    return "inventory-pill inventory-pill--warn" if product.low_stock?

    "inventory-pill inventory-pill--ok"
  end

  def order_status_badge_class(status)
    case status.to_s
    when "delivered"
      "manager-pill manager-pill--ok"
    when "cancelled"
      "manager-pill manager-pill--danger"
    when "out_for_delivery", "preparing", "confirmed"
      "manager-pill manager-pill--info"
    else
      "manager-pill manager-pill--warn"
    end
  end

  def payment_badge_class(status)
    case status.to_s
    when "paid"
      "manager-pill manager-pill--ok"
    when "failed", "refunded"
      "manager-pill manager-pill--danger"
    else
      "manager-pill manager-pill--warn"
    end
  end

  def role_responsibilities(role)
    User::RESPONSIBILITIES.fetch(role.to_sym)
  end

  def show_market_pulse?
    return false if @hide_site_chrome
    return false if portal_signed_in? || buyer_signed_in?

    controller_name.in?(%w[home products orders])
  end

  def market_pulse_messages
    messages = Rails.cache.fetch("storefront/market_pulse_messages", expires_in: 10.minutes) do
      recent_orders = Order.includes(order_items: :product).recent_first.limit(6)

      recent_orders.filter_map do |order|
        product = order.order_items.first&.product
        next unless product

        {
          message: "#{order.customer_name.to_s.split.first.presence || 'A shopper'} from #{market_pulse_location(order)} just picked #{product.name}",
          meta: "#{time_ago_in_words(order.created_at)} ago"
        }
      end
    end

    messages.presence || [
      { message: "A shopper from Indiranagar just picked Green Detox Juice", meta: "moments ago" },
      { message: "Fresh Alphonso mango baskets are moving fast this afternoon", meta: "live market pulse" },
      { message: "Veggie restock completed for tonight's same-day delivery slots", meta: "just updated" }
    ]
  end

  def order_tracking_steps(order)
    return cancelled_tracking_steps if order.cancelled?

    current_stage = order_tracking_stage(order)

    [
      {
        title: "Harvested",
        detail: "Fresh produce is reserved and moved into the fulfilment queue.",
        state: tracking_step_state(current_stage, 0)
      },
      {
        title: "Packed",
        detail: "Your box is assembled, sealed, and checked by the market team.",
        state: tracking_step_state(current_stage, 1)
      },
      {
        title: "On the way",
        detail: order.delivery_window.presence || "The rider route is assigned as soon as packing is complete.",
        state: tracking_step_state(current_stage, 2)
      },
      {
        title: "Delivered",
        detail: "Completed and marked as received at your doorstep.",
        state: tracking_step_state(current_stage, 3)
      }
    ]
  end

  def order_tracking_progress(order)
    return 0 if order.cancelled?

    ((order_tracking_stage(order) + 1).fdiv(4) * 100).round
  end

  def order_tracking_summary(order)
    case order.status.to_s
    when "pending"
      "Your order is locked in and waiting for the market team to start picking."
    when "confirmed", "preparing"
      "The kitchen and produce team are actively packing your basket."
    when "out_for_delivery"
      "Your order has left the market and is on the road now."
    when "delivered"
      "Delivered successfully. Enjoy the fresh haul."
    when "cancelled"
      "This order was cancelled before dispatch."
    else
      "We are preparing your order update."
    end
  end

  def business_postal_address
    {
      "@type" => "PostalAddress",
      "streetAddress" => "24 Market Road, Indiranagar",
      "addressLocality" => "Bengaluru",
      "addressRegion" => "Karnataka",
      "postalCode" => "560038",
      "addressCountry" => "IN"
    }
  end

  def location_page_schema(service_area)
    [
      {
        "@context" => "https://schema.org",
        "@type" => "GroceryStore",
        "name" => business_details[:name],
        "url" => location_page_url(service_area.slug),
        "telephone" => business_details[:phone],
        "email" => business_details[:email],
        "address" => business_postal_address,
        "areaServed" => service_area.full_name
      },
      {
        "@context" => "https://schema.org",
        "@type" => "WebPage",
        "name" => service_area.hero_title,
        "url" => location_page_url(service_area.slug),
        "description" => service_area.meta_description,
        "contentLocation" => {
          "@type" => "Place",
          "name" => service_area.full_name
        }
      }
    ]
  end

  private

  def cancelled_tracking_steps
    [
      {
        title: "Harvested",
        detail: "Stock was reserved when the order was first created.",
        state: "complete"
      },
      {
        title: "Packed",
        detail: "Packing did not continue because the order was cancelled before dispatch.",
        state: "current"
      },
      {
        title: "On the way",
        detail: "Delivery was never dispatched for this order.",
        state: "upcoming"
      },
      {
        title: "Delivered",
        detail: "The order was closed before reaching the doorstep.",
        state: "upcoming"
      }
    ]
  end

  def market_pulse_location(order)
    [order.address_line2, order.city, order.state]
      .compact_blank
      .map { |value| value.to_s.split(",").first.strip }
      .find(&:present?) || "Bengaluru"
  end

  def order_tracking_stage(order)
    case order.status.to_s
    when "pending"
      0
    when "confirmed", "preparing"
      1
    when "out_for_delivery"
      2
    when "delivered"
      3
    else
      0
    end
  end

  def tracking_step_state(current_stage, step_index)
    return "upcoming" if current_stage < step_index

    current_stage == step_index ? "current" : "complete"
  end

  def resolve_image_path(image_name)
    return image_path(image_name) if image_name.start_with?("veg-img/")

    "/#{image_name}"
  end
end
