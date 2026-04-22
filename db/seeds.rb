# This file should ensure the existence of records required to run the application in every environment (production,
# development, test). The code here should be idempotent so that it can be executed at any point in every environment.
# The data can then be loaded with the bin/rails db:seed command (or created alongside the database with db:setup).
#
# Example:
#
#   ["Action", "Comedy", "Drama", "Horror"].each do |genre_name|
#     MovieGenre.find_or_create_by!(name: genre_name)
#   end
puts "Seeding Vital Veggies & Juices..."

[ OrderItem, Order, Review, Product, Category, Promotion, Article, Faq, Testimonial, NewsletterSignup, User ].each(&:delete_all)

categories = [
  {
    name: "Fresh Juices",
    description: "Mosambi, aam panna, carrot-beetroot blends, smoothies, and immunity shots.",
    position: 1
  },
  {
    name: "Indian Fruits",
    description: "Mango, banana, guava, pomegranate, papaya, and seasonal fruit baskets.",
    position: 2
  },
  {
    name: "Fresh Vegetables",
    description: "Leafy greens, bhindi, tomatoes, carrots, potatoes, and kitchen staples.",
    position: 3
  },
  {
    name: "Family Combos",
    description: "Bundles that pair juices with curated fruit and vegetable packs.",
    position: 4
  }
].map { |attrs| Category.create!(attrs) }

products = [
  [ "Green Glow Juice", categories[0], :juice, 95, "Spinach, apple, cucumber, ginger, and lime for a clean green blend.", "Spinach, apple, cucumber, ginger, lime", true, true, true ],
  [ "Mosambi Mint Cooler", categories[0], :juice, 85, "Sweet lime, mint, ginger, and chilled coconut water.", "Mosambi, mint, ginger, coconut water", true, false, false ],
  [ "Carrot Beetroot Booster", categories[0], :juice, 90, "Carrot, beetroot, orange, and amla with a bright earthy finish.", "Carrot, beetroot, orange, amla", false, false, false ],
  [ "Alphonso Mango Basket", categories[1], :fruit, 399, "Seasonal mango selection packed for gifting or home use.", "Alphonso mangoes", true, true, true ],
  [ "Banana Guava Daily Box", categories[1], :fruit, 219, "Banana, guava, papaya, and pomegranate for everyday snacking.", "Banana, guava, papaya, pomegranate", true, true, false ],
  [ "Leafy Greens Sabzi Pack", categories[2], :vegetable, 149, "Palak, methi, coriander, pudina, and curry leaves.", "Palak, methi, coriander, pudina, curry leaves", false, true, true ],
  [ "Kitchen Veggie Crate", categories[2], :vegetable, 289, "Tomatoes, onions, potatoes, bhindi, carrots, cucumber, and green chillies.", "Mixed vegetables", false, false, true ],
  [ "Detox Weekender Combo", categories[3], :combo, 549, "Three fresh juices, one fruit basket, and one leafy greens pack.", "Mixed bundle", true, true, true ],
  [ "Family Fresh Combo", categories[3], :combo, 799, "A full produce bundle for weekly family meal prep with fruit and vegetables.", "Mixed bundle", false, false, true ]
]

products.each_with_index do |(name, category, kind, price, description, ingredients, featured, organic, local), index|
  Product.create!(
    category:,
    name:,
    sku: "VVJ-#{1000 + index}",
    description:,
    ingredients:,
    price:,
    stock_quantity: 12 + index,
    featured:,
    organic:,
    local:,
    seasonal: index.even?,
    active: true,
    product_kind: kind
  )
end

Promotion.create!(
  title: "Buy Fresh, Save More",
  description: "Get 10% off orders packed with juices, fruit, and vegetables.",
  discount_kind: :percentage,
  discount_value: 10,
  promo_code: "FRESH10",
  starts_on: Date.current - 2.days,
  ends_on: Date.current + 30.days,
  active: true,
  featured: true
)

Promotion.create!(
  title: "Free Delivery Weekend",
  description: "Enjoy a flat ₹80 discount on produce bundles and family carts.",
  discount_kind: :fixed_amount,
  discount_value: 80,
  promo_code: "DELIVER5",
  starts_on: Date.current - 1.day,
  ends_on: Date.current + 14.days,
  active: true,
  featured: true
)

Article.create!(
  title: "5 Benefits of Starting Your Morning with Fresh Juice",
  excerpt: "Learn why mosambi, greens, and hydration-focused blends work well as part of a morning routine.",
  body: "Fresh juice can be a quick way to increase fruit and vegetable intake at the start of the day.\n\nBlends with mosambi, greens, ginger, and amla provide bright flavor, hydration, and variety. Adding turmeric can create more depth and warmth.\n\nFor store owners, content like this helps customers discover new products while also supporting SEO for healthy lifestyle searches in Indian cities.",
  published: true,
  published_on: Date.current - 7.days,
  featured: true
)

Article.create!(
  title: "How to Build a Weekly Fruit and Vegetable Subscription Box",
  excerpt: "A simple guide to planning produce subscriptions for families, offices, and fitness-focused customers.",
  body: "Subscription boxes work best when they mix Indian kitchen staples with seasonal highlights.\n\nInclude one or two flexible options so customers can personalize their orders with sabzi essentials, fruit, and juices. Clear delivery windows and transparent pricing improve retention.\n\nA dedicated landing section on the homepage can help convert repeat orders.",
  published: true,
  published_on: Date.current - 5.days,
  featured: true
)

Article.create!(
  title: "Three Juice Recipes Customers Love in Summer",
  excerpt: "These bright, fruit-forward juice recipes are easy to feature in seasonal promotions.",
  body: "Summer menus perform well when they balance sweetness and freshness.\n\nAam panna coolers, watermelon mint refreshers, and pineapple-ginger blends are easy favorites.\n\nPair recipes with a featured fruit basket or combo offer to improve average order value.",
  published: true,
  published_on: Date.current - 2.days,
  featured: true
)

[
  [ "Do you offer same-day delivery?", "Yes. Orders placed before noon are usually eligible for same-day local delivery.", 1 ],
  [ "Can I order only fruit or only vegetables?", "Yes. You can shop each category separately or mix them in one cart.", 2 ],
  [ "Do you stock organic produce?", "Yes. Organic items are clearly labeled and can be filtered from the catalog page.", 3 ],
  [ "How do coupons work?", "Apply a valid coupon code in the cart before checkout. Eligible discounts appear immediately.", 4 ],
  [ "Can I track my order?", "Yes. Each order receives an order number and status page after checkout.", 5 ]
].each do |question, answer, position|
  Faq.create!(question:, answer:, position:)
end

[
  [ "Amelia R.", "Weekly customer", "The combo packs save us time every week, and the juice quality is consistently excellent.", 5 ],
  [ "Jordan P.", "Gym coach", "The green juices and fruit boxes are a hit with our clients after sessions.", 5 ],
  [ "Sofia L.", "Office manager", "Delivery is reliable, and the produce is always fresh enough for team snack tables.", 4 ]
].each do |name, role, quote, rating|
  Testimonial.create!(customer_name: name, role:, quote:, rating:, featured: true)
end

Product.limit(4).each_with_index do |product, index|
  Review.create!(
    product:,
    customer_name: [ "Maya", "Chris", "Elena", "Noah" ][index],
    title: "Fresh and well packed",
    body: "Ordering was simple, the product arrived fresh, and the quality matched the description on the site.",
    rating: 4 + (index % 2),
    approved: true
  )
end

admin = User.new(
  email: "admin@vitalveggies.in",
  name: "Admin Control",
  role: :admin,
  active: true,
  registered_at: Time.current
)
admin.password = "Admin@12345"
admin.password_confirmation = "Admin@12345"
admin.save!

buyer = User.new(
  email: "buyer@vitalveggies.in",
  name: "Demo Buyer",
  role: :buyer,
  active: true,
  registered_at: Time.current
)
buyer.password = "Buyer@12345"
buyer.password_confirmation = "Buyer@12345"
buyer.save!

puts "Seed complete."
