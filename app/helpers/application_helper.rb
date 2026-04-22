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
    return "Sold out" unless product.in_stock?
    return "Low stock" if product.low_stock?

    "In stock"
  end

  def stock_badge_class(product)
    return "inventory-pill inventory-pill--danger" unless product.in_stock?
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

  def resolve_image_path(image_name)
    return image_path(image_name) if image_name.start_with?("veg-img/")

    "/#{image_name}"
  end
end
