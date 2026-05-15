module LocalDbAi
  # Fast SQL template engine — handles ~90% of common queries in <5ms.
  # Only falls through to Ollama when no template matches.
  class SqlTemplateEngine
    Result = Struct.new(:sql, :summary, :matched, keyword_init: true)

    # Each pattern: [regex, sql_lambda, summary_lambda]
    TEMPLATES = [
      # ── Single-word / bare keyword shortcuts ──────────────────────────────────
      [
        /\A(orders?[?!.]?)\z/i,
        ->(_m) { "SELECT id, order_number, customer_name, status, total, payment_status, created_at FROM orders ORDER BY created_at DESC LIMIT 200" },
        ->(_m) { "All orders listed newest first." }
      ],
      [
        /\A(revenue[?!.]?|sales[?!.]?)\z/i,
        ->(_m) { "SELECT SUM(total) AS total_revenue, COUNT(*) AS order_count, ROUND(AVG(total)::numeric,2) AS avg_order_value FROM orders" },
        ->(_m) { "Total revenue, order count, and average order value." }
      ],
      [
        /\A(products?[?!.]?|inventory[?!.]?)\z/i,
        ->(_m) { "SELECT id, name, sku, price, stock_quantity, active, product_kind FROM products ORDER BY name" },
        ->(_m) { "All products with stock and pricing." }
      ],
      [
        /\A(customers?[?!.]?)\z/i,
        ->(_m) { "SELECT u.id, u.name, u.email, u.created_at, COUNT(o.id) AS order_count FROM users u LEFT JOIN orders o ON o.user_id = u.id WHERE u.role = 2 GROUP BY u.id, u.name, u.email, u.created_at ORDER BY order_count DESC" },
        ->(_m) { "All customers with their order counts." }
      ],
      [
        /\A(reviews?[?!.]?)\z/i,
        ->(_m) { "SELECT id, customer_name, rating, title, approved, created_at FROM reviews ORDER BY created_at DESC" },
        ->(_m) { "All customer reviews." }
      ],
      [
        /\A(promotions?[?!.]?|coupons?[?!.]?)\z/i,
        ->(_m) { "SELECT id, code, discount_type, discount_value, active, starts_at, ends_at FROM promotions ORDER BY created_at DESC" },
        ->(_m) { "All promotions and coupon codes." }
      ],
      [
        /\A(summary[?!.]?|overview[?!.]?|dashboard[?!.]?)\z/i,
        ->(_m) { "SELECT (SELECT COUNT(*) FROM orders) AS total_orders, (SELECT ROUND(SUM(total)::numeric,2) FROM orders) AS total_revenue, (SELECT COUNT(*) FROM orders WHERE created_at::date = CURRENT_DATE) AS orders_today, (SELECT COUNT(*) FROM orders WHERE status IN (0,1,2,3)) AS open_orders, (SELECT COUNT(*) FROM products WHERE active = true) AS active_products, (SELECT COUNT(*) FROM products WHERE stock_quantity < 10) AS low_stock_products, (SELECT COUNT(*) FROM users WHERE role = 2) AS total_customers, (SELECT COUNT(*) FROM reviews WHERE approved = false) AS pending_reviews" },
        ->(_m) { "Full store overview." }
      ],
      [
        /\A(stock[?!.]?)\z/i,
        ->(_m) { "SELECT id, name, sku, stock_quantity, price FROM products WHERE stock_quantity < 10 ORDER BY stock_quantity ASC" },
        ->(_m) { "Products with low stock (below 10 units)." }
      ],
      [
        /\A(delivered[?!.]?)\z/i,
        ->(_m) { "SELECT id, order_number, customer_name, total, created_at FROM orders WHERE status = 4 ORDER BY created_at DESC" },
        ->(_m) { "All delivered orders." }
      ],
      [
        /\A(pending[?!.]?)\z/i,
        ->(_m) { "SELECT id, order_number, customer_name, total, created_at FROM orders WHERE status = 0 ORDER BY created_at DESC" },
        ->(_m) { "All pending orders." }
      ],
      [
        /\A(cancelled[?!.]?|canceled[?!.]?)\z/i,
        ->(_m) { "SELECT id, order_number, customer_name, total, created_at FROM orders WHERE status = 5 ORDER BY created_at DESC" },
        ->(_m) { "All cancelled orders." }
      ],
      [
        /\A(confirmed[?!.]?)\z/i,
        ->(_m) { "SELECT id, order_number, customer_name, total, created_at FROM orders WHERE status = 1 ORDER BY created_at DESC" },
        ->(_m) { "All confirmed orders." }
      ],
      [
        /\A(preparing[?!.]?)\z/i,
        ->(_m) { "SELECT id, order_number, customer_name, total, created_at FROM orders WHERE status = 2 ORDER BY created_at DESC" },
        ->(_m) { "Orders currently being prepared." }
      ],
      [
        /\A(faqs?[?!.]?)\z/i,
        ->(_m) { "SELECT id, question, answer, position FROM faqs ORDER BY position ASC" },
        ->(_m) { "All FAQ entries." }
      ],
      [
        /\A(testimonials?[?!.]?)\z/i,
        ->(_m) { "SELECT id, customer_name, role, quote, rating, featured, created_at FROM testimonials ORDER BY created_at DESC" },
        ->(_m) { "All customer testimonials." }
      ],
      [
        /\A(articles?[?!.]?|blogs?[?!.]?)\z/i,
        ->(_m) { "SELECT id, title, slug, published, featured, created_at FROM articles ORDER BY created_at DESC" },
        ->(_m) { "All blog articles." }
      ],
      [
        /\A(categories?[?!.]?)\z/i,
        ->(_m) { "SELECT id, name, slug, active, position FROM categories ORDER BY position ASC" },
        ->(_m) { "All product categories." }
      ],
      [
        /\A(managers?[?!.]?)\z/i,
        ->(_m) { "SELECT id, name, email, active, registered_at FROM users WHERE role = 1 ORDER BY created_at DESC" },
        ->(_m) { "All manager accounts." }
      ],
      [
        /\A(newsletter[?!.]?|subscribers?[?!.]?)\z/i,
        ->(_m) { "SELECT COUNT(*) AS total_signups, COUNT(*) FILTER (WHERE active = true) AS active_subscribers FROM newsletter_signups" },
        ->(_m) { "Total newsletter signups and active subscribers." }
      ],
      [
        /\A(combos?[?!.]?|bundles?[?!.]?)\z/i,
        ->(_m) { "SELECT id, name, sku, price, stock_quantity, active FROM products WHERE product_kind = 3 ORDER BY name" },
        ->(_m) { "All combo/bundle products." }
      ],

      # ── Orders: status ────────────────────────────────────────────────────────
      [
        /\ball\s+orders\b|show\s+(me\s+)?all\s+orders|list\s+(of\s+)?all\s+orders/i,
        ->(_m) { "SELECT id, order_number, customer_name, status, total, payment_status, created_at FROM orders ORDER BY created_at DESC LIMIT 200" },
        ->(_m) { "All orders listed newest first." }
      ],
      [
        /delivered\s+orders?|orders?\s+delivered|status.*delivered/i,
        ->(_m) { "SELECT id, order_number, customer_name, total, created_at FROM orders WHERE status = 4 ORDER BY created_at DESC" },
        ->(_m) { "All delivered orders." }
      ],
      [
        /pending\s+orders?|orders?\s+(that are\s+)?pending/i,
        ->(_m) { "SELECT id, order_number, customer_name, total, created_at FROM orders WHERE status = 0 ORDER BY created_at DESC" },
        ->(_m) { "All pending orders." }
      ],
      [
        /confirmed\s+orders?|orders?\s+(that are\s+)?confirmed/i,
        ->(_m) { "SELECT id, order_number, customer_name, total, created_at FROM orders WHERE status = 1 ORDER BY created_at DESC" },
        ->(_m) { "All confirmed orders." }
      ],
      [
        /preparing\s+orders?|orders?\s+(being\s+)?prepared|orders?\s+in\s+preparation/i,
        ->(_m) { "SELECT id, order_number, customer_name, total, created_at FROM orders WHERE status = 2 ORDER BY created_at DESC" },
        ->(_m) { "Orders currently being prepared." }
      ],
      [
        /out\s+for\s+delivery|orders?\s+out\s+for\s+delivery|on\s+the\s+way/i,
        ->(_m) { "SELECT id, order_number, customer_name, total, created_at FROM orders WHERE status = 3 ORDER BY created_at DESC" },
        ->(_m) { "Orders currently out for delivery." }
      ],
      [
        /cancelled\s+orders?|orders?\s+cancelled/i,
        ->(_m) { "SELECT id, order_number, customer_name, total, created_at FROM orders WHERE status = 5 ORDER BY created_at DESC" },
        ->(_m) { "All cancelled orders." }
      ],
      [
        /open\s+orders?|active\s+orders?|unfulfilled\s+orders?|orders?\s+in\s+progress/i,
        ->(_m) { "SELECT id, order_number, customer_name, status, total, created_at FROM orders WHERE status IN (0,1,2,3) ORDER BY created_at ASC" },
        ->(_m) { "All open/active orders not yet delivered or cancelled." }
      ],

      # ── Orders: time-based ────────────────────────────────────────────────────
      [
        /orders?\s+(from\s+)?today|today'?s?\s+orders?/i,
        ->(_m) { "SELECT id, order_number, customer_name, status, total, created_at FROM orders WHERE created_at::date = CURRENT_DATE ORDER BY created_at DESC" },
        ->(_m) { "Orders placed today." }
      ],
      [
        /orders?\s+(from\s+)?yesterday|yesterday'?s?\s+orders?/i,
        ->(_m) { "SELECT id, order_number, customer_name, status, total, created_at FROM orders WHERE created_at::date = CURRENT_DATE - INTERVAL '1 day' ORDER BY created_at DESC" },
        ->(_m) { "Orders placed yesterday." }
      ],
      [
        /orders?\s+(within|in(\s+the)?\s+last|past)\s+(\d+)\s+hours?|last\s+(\d+)\s+hours?\s+orders?/i,
        ->(m) { n = m[3] || m[4]; "SELECT id, order_number, customer_name, status, total, created_at FROM orders WHERE created_at >= NOW() - INTERVAL '#{n} hours' ORDER BY created_at DESC" },
        ->(m) { n = m[3] || m[4]; "Orders placed in the last #{n} hours." }
      ],
      [
        /orders?\s+(of\s+|in\s+|last\s+|past\s+|from\s+last\s+)?(\d+)\s+days?/i,
        ->(m) { n = m[2]; "SELECT id, order_number, customer_name, status, total, created_at FROM orders WHERE created_at >= NOW() - INTERVAL '#{n} days' ORDER BY created_at DESC" },
        ->(m) { "Orders from the last #{m[2]} days." }
      ],
      [
        /orders?\s+(this\s+week|current\s+week)/i,
        ->(_m) { "SELECT id, order_number, customer_name, status, total, created_at FROM orders WHERE date_trunc('week', created_at) = date_trunc('week', NOW()) ORDER BY created_at DESC" },
        ->(_m) { "Orders placed this week." }
      ],
      [
        /orders?\s+(last\s+week|previous\s+week)/i,
        ->(_m) { "SELECT id, order_number, customer_name, status, total, created_at FROM orders WHERE date_trunc('week', created_at) = date_trunc('week', NOW() - INTERVAL '1 week') ORDER BY created_at DESC" },
        ->(_m) { "Orders placed last week." }
      ],
      [
        /orders?\s+(this\s+month|current\s+month)/i,
        ->(_m) { "SELECT id, order_number, customer_name, status, total, created_at FROM orders WHERE date_trunc('month', created_at) = date_trunc('month', NOW()) ORDER BY created_at DESC" },
        ->(_m) { "Orders placed this month." }
      ],
      [
        /orders?\s+(last\s+month|previous\s+month)/i,
        ->(_m) { "SELECT id, order_number, customer_name, status, total, created_at FROM orders WHERE date_trunc('month', created_at) = date_trunc('month', NOW() - INTERVAL '1 month') ORDER BY created_at DESC" },
        ->(_m) { "Orders placed last month." }
      ],
      [
        /\b(jan(?:uary)?|feb(?:ruary)?|mar(?:ch)?|apr(?:il)?|may|jun(?:e)?|jul(?:y)?|aug(?:ust)?|sep(?:tember)?|oct(?:ober)?|nov(?:ember)?|dec(?:ember)?)\b.*orders?|orders?.*\b(jan(?:uary)?|feb(?:ruary)?|mar(?:ch)?|apr(?:il)?|may|jun(?:e)?|jul(?:y)?|aug(?:ust)?|sep(?:tember)?|oct(?:ober)?|nov(?:ember)?|dec(?:ember)?)\b/i,
        ->(m) { month = (m[1] || m[2]); num = month_number(month); "SELECT id, order_number, customer_name, status, total, created_at FROM orders WHERE EXTRACT(MONTH FROM created_at) = #{num} AND EXTRACT(YEAR FROM created_at) = EXTRACT(YEAR FROM NOW()) ORDER BY created_at DESC" },
        ->(m) { month = (m[1] || m[2]); "Orders placed in #{month.capitalize}." }
      ],

      # ── Orders: customer / coupon ─────────────────────────────────────────────
      [
        /orders?\s+(?:by|from|of|for)\s+(?:customer\s+)?(.+)/i,
        ->(m) { name = m[1].strip.gsub("'", "''"); "SELECT id, order_number, customer_name, status, total, created_at FROM orders WHERE LOWER(customer_name) LIKE LOWER('%#{name}%') ORDER BY created_at DESC" },
        ->(m) { "Orders placed by customers matching '#{m[1].strip}'." }
      ],
      [
        /orders?\s+with\s+coupon|coupon\s+orders?/i,
        ->(_m) { "SELECT id, order_number, customer_name, coupon_code, discount_total, total, created_at FROM orders WHERE coupon_code IS NOT NULL ORDER BY created_at DESC" },
        ->(_m) { "Orders where a coupon code was applied." }
      ],
      [
        /orders?\s+with\s+discount|discounted\s+orders?/i,
        ->(_m) { "SELECT id, order_number, customer_name, coupon_code, discount_total, total, created_at FROM orders WHERE discount_total > 0 ORDER BY discount_total DESC" },
        ->(_m) { "Orders where a discount was applied." }
      ],
      [
        /high(?:est)?\s+value\s+orders?|largest\s+orders?|biggest\s+orders?|top\s+orders?\s+by\s+value/i,
        ->(_m) { "SELECT id, order_number, customer_name, status, total, created_at FROM orders ORDER BY total DESC LIMIT 20" },
        ->(_m) { "Top 20 highest-value orders." }
      ],
      [
        /order\s+count|how\s+many\s+orders?|total\s+orders?|number\s+of\s+orders?/i,
        ->(_m) { "SELECT COUNT(*) AS order_count FROM orders" },
        ->(_m) { "Total number of orders." }
      ],
      [
        /daily\s+orders?|orders?\s+per\s+day|orders?\s+by\s+day/i,
        ->(_m) { "SELECT created_at::date AS day, COUNT(*) AS order_count, SUM(total) AS revenue FROM orders GROUP BY created_at::date ORDER BY day DESC LIMIT 30" },
        ->(_m) { "Daily order count and revenue for the last 30 days." }
      ],
      [
        /weekly\s+orders?|orders?\s+per\s+week|orders?\s+by\s+week/i,
        ->(_m) { "SELECT DATE_TRUNC('week', created_at)::date AS week_start, COUNT(*) AS order_count, SUM(total) AS revenue FROM orders GROUP BY DATE_TRUNC('week', created_at) ORDER BY week_start DESC LIMIT 12" },
        ->(_m) { "Weekly order count and revenue (last 12 weeks)." }
      ],
      [
        /orders?\s+with\s+delivery\s+fee|delivery\s+fee\s+orders?/i,
        ->(_m) { "SELECT id, order_number, customer_name, delivery_fee, total, created_at FROM orders WHERE delivery_fee > 0 ORDER BY delivery_fee DESC" },
        ->(_m) { "Orders that included a delivery fee." }
      ],

      # ── Revenue ───────────────────────────────────────────────────────────────
      [
        /total\s+revenue|overall\s+revenue|all\s+(?:time\s+)?revenue|how\s+much\s+(have\s+we\s+made|did\s+we\s+make|money)/i,
        ->(_m) { "SELECT SUM(total) AS total_revenue, COUNT(*) AS order_count, ROUND(AVG(total)::numeric, 2) AS avg_order_value FROM orders" },
        ->(_m) { "Total revenue, order count, and average order value across all orders." }
      ],
      [
        /revenue\s+(within|in(\s+the)?\s+last|past)\s+(\d+)\s+hours?/i,
        ->(m) { n = m[3]; "SELECT SUM(total) AS revenue, COUNT(*) AS order_count FROM orders WHERE created_at >= NOW() - INTERVAL '#{n} hours'" },
        ->(m) { "Revenue from the last #{m[3]} hours." }
      ],
      [
        /revenue\s+(of\s+|in\s+|last\s+|past\s+)?(\d+)\s+days?|(\d+)\s+days?\s+revenue/i,
        ->(m) { n = m[2] || m[3]; "SELECT SUM(total) AS total_revenue, COUNT(*) AS order_count FROM orders WHERE created_at >= NOW() - INTERVAL '#{n} days'" },
        ->(m) { n = m[2] || m[3]; "Revenue from the last #{n} days." }
      ],
      [
        /revenue\s+(this\s+week)|this\s+week'?s?\s+revenue/i,
        ->(_m) { "SELECT SUM(total) AS total_revenue, COUNT(*) AS order_count FROM orders WHERE date_trunc('week', created_at) = date_trunc('week', NOW())" },
        ->(_m) { "Revenue earned this week." }
      ],
      [
        /revenue\s+(last\s+week)|last\s+week'?s?\s+revenue/i,
        ->(_m) { "SELECT SUM(total) AS total_revenue, COUNT(*) AS order_count FROM orders WHERE date_trunc('week', created_at) = date_trunc('week', NOW() - INTERVAL '1 week')" },
        ->(_m) { "Revenue earned last week." }
      ],
      [
        /revenue\s+(this\s+month)|this\s+month'?s?\s+revenue/i,
        ->(_m) { "SELECT SUM(total) AS total_revenue, COUNT(*) AS order_count FROM orders WHERE date_trunc('month', created_at) = date_trunc('month', NOW())" },
        ->(_m) { "Revenue earned this month." }
      ],
      [
        /revenue\s+(last\s+month)|last\s+month'?s?\s+revenue/i,
        ->(_m) { "SELECT SUM(total) AS total_revenue, COUNT(*) AS order_count FROM orders WHERE date_trunc('month', created_at) = date_trunc('month', NOW() - INTERVAL '1 month')" },
        ->(_m) { "Revenue earned last month." }
      ],
      [
        /monthly\s+revenue|revenue\s+(by|per)\s+month|revenue\s+breakdown/i,
        ->(_m) { "SELECT TO_CHAR(created_at, 'Month YYYY') AS month, SUM(total) AS revenue, COUNT(*) AS order_count FROM orders GROUP BY DATE_TRUNC('month', created_at), TO_CHAR(created_at, 'Month YYYY') ORDER BY DATE_TRUNC('month', created_at)" },
        ->(_m) { "Monthly revenue and order count breakdown." }
      ],
      [
        /weekly\s+revenue|revenue\s+(by|per)\s+week/i,
        ->(_m) { "SELECT DATE_TRUNC('week', created_at)::date AS week_start, SUM(total) AS revenue, COUNT(*) AS order_count FROM orders GROUP BY DATE_TRUNC('week', created_at) ORDER BY week_start DESC LIMIT 12" },
        ->(_m) { "Weekly revenue breakdown (last 12 weeks)." }
      ],
      [
        /daily\s+revenue|revenue\s+(by|per)\s+day/i,
        ->(_m) { "SELECT created_at::date AS day, SUM(total) AS revenue, COUNT(*) AS order_count FROM orders GROUP BY created_at::date ORDER BY day DESC LIMIT 30" },
        ->(_m) { "Daily revenue for the last 30 days." }
      ],
      [
        /average\s+order|avg\s+order|mean\s+order/i,
        ->(_m) { "SELECT ROUND(AVG(total)::numeric, 2) AS avg_order_value, COUNT(*) AS order_count, SUM(total) AS total_revenue FROM orders" },
        ->(_m) { "Average order value across all orders." }
      ],
      [
        /revenue\s+today|today'?s?\s+revenue/i,
        ->(_m) { "SELECT SUM(total) AS revenue, COUNT(*) AS order_count FROM orders WHERE created_at::date = CURRENT_DATE" },
        ->(_m) { "Revenue earned today." }
      ],
      [
        /revenue\s+yesterday|yesterday'?s?\s+revenue/i,
        ->(_m) { "SELECT SUM(total) AS revenue, COUNT(*) AS order_count FROM orders WHERE created_at::date = CURRENT_DATE - INTERVAL '1 day'" },
        ->(_m) { "Revenue earned yesterday." }
      ],
      [
        /revenue\s+by\s+(?:product|item)|product\s+revenue/i,
        ->(_m) { "SELECT oi.product_name, SUM(oi.quantity) AS units_sold, SUM(oi.line_total) AS revenue FROM order_items oi GROUP BY oi.product_name ORDER BY revenue DESC" },
        ->(_m) { "Revenue broken down by product." }
      ],
      [
        /discount\s+(?:total|given|impact)|total\s+discount/i,
        ->(_m) { "SELECT SUM(discount_total) AS total_discount, COUNT(*) AS discounted_orders, ROUND(AVG(discount_total)::numeric,2) AS avg_discount FROM orders WHERE discount_total > 0" },
        ->(_m) { "Total discount amount given across all orders." }
      ],
      [
        /delivery\s+fee\s+(?:total|revenue|collected)|total\s+delivery\s+fees?/i,
        ->(_m) { "SELECT SUM(delivery_fee) AS total_delivery_fees, COUNT(*) AS orders_with_fee FROM orders WHERE delivery_fee > 0" },
        ->(_m) { "Total delivery fees collected." }
      ],

      # ── Products: all / type / attribute ─────────────────────────────────────
      [
        /\ball\s+products?|show\s+(me\s+)?all\s+products?|list\s+(of\s+)?products?/i,
        ->(_m) { "SELECT id, name, sku, price, stock_quantity, active, product_kind FROM products ORDER BY name" },
        ->(_m) { "All products with stock and pricing." }
      ],
      [
        /low\s+stock|running\s+out|out\s+of\s+stock|stock\s+(is\s+)?less\s+than\s+(\d+)|products?\s+stock.*less/i,
        ->(m) { n = m[2] || "10"; "SELECT id, name, sku, stock_quantity, price FROM products WHERE stock_quantity < #{n} ORDER BY stock_quantity ASC" },
        ->(m) { n = m[2] || "10"; "Products with stock below #{n} units." }
      ],
      [
        /out\s+of\s+stock\s+products?|zero\s+stock|no\s+stock/i,
        ->(_m) { "SELECT id, name, sku, price FROM products WHERE stock_quantity = 0 ORDER BY name" },
        ->(_m) { "Products with zero stock." }
      ],
      [
        /top\s+(\d+)\s+(selling|sold|products?|selling\s+products?)|best\s+seller/i,
        ->(m) { n = m[1] || "5"; "SELECT oi.product_name, SUM(oi.quantity) AS units_sold, SUM(oi.line_total) AS revenue FROM order_items oi JOIN orders o ON o.id = oi.order_id GROUP BY oi.product_name ORDER BY revenue DESC LIMIT #{n}" },
        ->(m) { n = m[1] || "5"; "Top #{n} best-selling products by revenue." }
      ],
      [
        /least\s+(?:selling|sold|popular)\s+products?|worst\s+(?:selling|performing)\s+products?/i,
        ->(_m) { "SELECT oi.product_name, SUM(oi.quantity) AS units_sold, SUM(oi.line_total) AS revenue FROM order_items oi GROUP BY oi.product_name ORDER BY revenue ASC LIMIT 10" },
        ->(_m) { "Least selling products by revenue." }
      ],
      [
        /products?\s+(with\s+)?price\s+(up\s+to|below|less\s+than|under)\s+(\d+)|products?\s+(under|below)\s+(\d+)/i,
        ->(m) { n = m[3] || m[5]; "SELECT id, name, sku, price, stock_quantity FROM products WHERE price <= #{n} ORDER BY price ASC" },
        ->(m) { n = m[3] || m[5]; "Products priced at ₹#{n} or below." }
      ],
      [
        /products?\s+(with\s+)?price\s+(above|more\s+than|greater\s+than|over)\s+(\d+)|products?\s+(above|over)\s+(\d+)/i,
        ->(m) { n = m[3] || m[5]; "SELECT id, name, sku, price, stock_quantity FROM products WHERE price > #{n} ORDER BY price DESC" },
        ->(m) { n = m[3] || m[5]; "Products priced above ₹#{n}." }
      ],
      [
        /most\s+expensive\s+products?|highest\s+priced\s+products?/i,
        ->(_m) { "SELECT id, name, sku, price, stock_quantity FROM products ORDER BY price DESC LIMIT 10" },
        ->(_m) { "Top 10 most expensive products." }
      ],
      [
        /cheapest\s+products?|lowest\s+priced\s+products?/i,
        ->(_m) { "SELECT id, name, sku, price, stock_quantity FROM products WHERE active = true ORDER BY price ASC LIMIT 10" },
        ->(_m) { "10 cheapest active products." }
      ],
      [
        /organic\s+products?|products?\s+(that\s+are\s+)?organic/i,
        ->(_m) { "SELECT id, name, sku, price, stock_quantity FROM products WHERE organic = true ORDER BY name" },
        ->(_m) { "All organic products." }
      ],
      [
        /local\s+products?|products?\s+(that\s+are\s+)?local/i,
        ->(_m) { "SELECT id, name, sku, price, stock_quantity FROM products WHERE local = true ORDER BY name" },
        ->(_m) { "All locally sourced products." }
      ],
      [
        /seasonal\s+products?|products?\s+(that\s+are\s+)?seasonal/i,
        ->(_m) { "SELECT id, name, sku, price, stock_quantity FROM products WHERE seasonal = true ORDER BY name" },
        ->(_m) { "All seasonal products." }
      ],
      [
        /featured\s+products?|products?\s+(that\s+are\s+)?featured/i,
        ->(_m) { "SELECT id, name, sku, price, stock_quantity FROM products WHERE featured = true ORDER BY name" },
        ->(_m) { "All featured products." }
      ],
      [
        /inactive\s+products?|disabled\s+products?|products?\s+not\s+active/i,
        ->(_m) { "SELECT id, name, sku, price, stock_quantity FROM products WHERE active = false ORDER BY name" },
        ->(_m) { "All inactive/disabled products." }
      ],
      [
        /juice\s+products?|products?\s+(that\s+are\s+)?juice/i,
        ->(_m) { "SELECT id, name, sku, price, stock_quantity FROM products WHERE product_kind = 0 ORDER BY name" },
        ->(_m) { "All juice products." }
      ],
      [
        /fruit\s+products?|products?\s+(that\s+are\s+)?fruit/i,
        ->(_m) { "SELECT id, name, sku, price, stock_quantity FROM products WHERE product_kind = 1 ORDER BY name" },
        ->(_m) { "All fruit products." }
      ],
      [
        /veg(?:etable)?\s+products?|products?\s+(that\s+are\s+)?veg(?:etable)?/i,
        ->(_m) { "SELECT id, name, sku, price, stock_quantity FROM products WHERE product_kind = 2 ORDER BY name" },
        ->(_m) { "All vegetable products." }
      ],
      [
        /combo\s+items?|combo\s+products?|bundle(?:s|\s+products?)?|pack(?:s|\s+products?)?|products?\s+(that\s+are\s+)?combo/i,
        ->(_m) { "SELECT id, name, sku, price, stock_quantity, active FROM products WHERE product_kind = 3 ORDER BY name" },
        ->(_m) { "All combo/bundle products." }
      ],
      [
        /low\s+stock\s+combo|combo\s+low\s+stock/i,
        ->(_m) { "SELECT id, name, sku, price, stock_quantity FROM products WHERE product_kind = 3 AND stock_quantity < 10 ORDER BY stock_quantity ASC" },
        ->(_m) { "Combo products running low on stock." }
      ],
      [
        /top\s+combo\s+products?|best\s+(?:selling\s+)?combo/i,
        ->(_m) { "SELECT oi.product_name, SUM(oi.quantity) AS units_sold, SUM(oi.line_total) AS revenue FROM order_items oi JOIN products p ON p.name = oi.product_name WHERE p.product_kind = 3 GROUP BY oi.product_name ORDER BY revenue DESC LIMIT 5" },
        ->(_m) { "Top combo products by revenue." }
      ],
      [
        /combo\s+(?:orders?|sales?)|orders?\s+with\s+combo/i,
        ->(_m) { "SELECT DISTINCT o.id, o.order_number, o.customer_name, o.status, o.total, o.created_at FROM orders o JOIN order_items oi ON oi.order_id = o.id JOIN products p ON p.name = oi.product_name WHERE p.product_kind = 3 ORDER BY o.created_at DESC LIMIT 200" },
        ->(_m) { "Orders containing at least one combo product." }
      ],
      [
        /combo\s+revenue|revenue\s+from\s+combo/i,
        ->(_m) { "SELECT SUM(oi.line_total) AS combo_revenue, SUM(oi.quantity) AS units_sold FROM order_items oi JOIN products p ON p.name = oi.product_name WHERE p.product_kind = 3" },
        ->(_m) { "Total revenue generated from combo products." }
      ],
      [
        /bulk\s+orders?/i,
        ->(_m) { "SELECT o.id, o.order_number, o.customer_name, o.status, o.total, o.created_at, SUM(oi.quantity) AS total_items FROM orders o JOIN order_items oi ON oi.order_id = o.id GROUP BY o.id, o.order_number, o.customer_name, o.status, o.total, o.created_at HAVING SUM(oi.quantity) >= 5 ORDER BY total_items DESC LIMIT 200" },
        ->(_m) { "Orders with 5 or more total items (bulk orders)." }
      ],
      [
        /bulk\s+items?|bulk\s+products?/i,
        ->(_m) { "SELECT oi.product_name, SUM(oi.quantity) AS total_quantity, SUM(oi.line_total) AS revenue FROM order_items oi GROUP BY oi.product_name HAVING SUM(oi.quantity) >= 50 ORDER BY total_quantity DESC" },
        ->(_m) { "Products sold in bulk (50+ units total)." }
      ],
      [
        /product\s+type(?:s)?\s+breakdown|breakdown\s+by\s+(?:product\s+)?type/i,
        ->(_m) { "SELECT CASE product_kind WHEN 0 THEN 'Juice' WHEN 1 THEN 'Fruit' WHEN 2 THEN 'Vegetable' WHEN 3 THEN 'Combo' END AS type, COUNT(*) AS count, SUM(stock_quantity) AS total_stock FROM products GROUP BY product_kind ORDER BY product_kind" },
        ->(_m) { "Product count and stock grouped by type." }
      ],
      [
        /total\s+(?:products?|inventory)|how\s+many\s+products?|product\s+count/i,
        ->(_m) { "SELECT COUNT(*) AS total_products, COUNT(*) FILTER (WHERE active = true) AS active_products, COUNT(*) FILTER (WHERE active = false) AS inactive_products FROM products" },
        ->(_m) { "Total product count broken down by active vs inactive." }
      ],
      [
        /inventory\s+value|stock\s+value|total\s+stock\s+worth/i,
        ->(_m) { "SELECT SUM(price * stock_quantity) AS total_inventory_value, COUNT(*) AS product_count FROM products WHERE active = true" },
        ->(_m) { "Total monetary value of current inventory." }
      ],
      [
        /never\s+sold\s+products?|products?\s+(?:never|not)\s+(?:been\s+)?sold|unsold\s+products?/i,
        ->(_m) { "SELECT p.id, p.name, p.sku, p.price, p.stock_quantity FROM products p LEFT JOIN order_items oi ON oi.product_id = p.id WHERE oi.id IS NULL ORDER BY p.name" },
        ->(_m) { "Products that have never been ordered." }
      ],

      # ── Customers / Users ─────────────────────────────────────────────────────
      [
        /all\s+customers?|customer\s+list|list\s+(?:of\s+)?customers?/i,
        ->(_m) { "SELECT u.id, u.name, u.email, u.created_at, COUNT(o.id) AS order_count FROM users u LEFT JOIN orders o ON o.user_id = u.id WHERE u.role = 'buyer' GROUP BY u.id, u.name, u.email, u.created_at ORDER BY order_count DESC" },
        ->(_m) { "All customers with their total order counts." }
      ],
      [
        /top\s+(?:(\d+)\s+)?customers?|best\s+customers?|highest\s+spending\s+customers?/i,
        ->(m) { n = m[1] || "10"; "SELECT u.name, u.email, COUNT(o.id) AS order_count, SUM(o.total) AS total_spent FROM users u JOIN orders o ON o.user_id = u.id WHERE u.role = 'buyer' GROUP BY u.id, u.name, u.email ORDER BY total_spent DESC LIMIT #{n}" },
        ->(m) { n = m[1] || "10"; "Top #{n} customers by total spend." }
      ],
      [
        /repeat\s+customers?|customers?\s+with\s+more\s+than\s+(\d+)\s+orders?|loyal\s+customers?/i,
        ->(m) { n = m[1] || "1"; "SELECT u.name, u.email, COUNT(o.id) AS order_count, SUM(o.total) AS total_spent FROM users u JOIN orders o ON o.user_id = u.id WHERE u.role = 'buyer' GROUP BY u.id, u.name, u.email HAVING COUNT(o.id) > #{n} ORDER BY order_count DESC" },
        ->(m) { n = m[1] || "1"; "Customers with more than #{n} orders (repeat customers)." }
      ],
      [
        /new\s+customers?\s+today|customers?\s+(?:joined|registered|signed\s+up)\s+today/i,
        ->(_m) { "SELECT id, name, email, created_at FROM users WHERE role = 'buyer' AND created_at::date = CURRENT_DATE ORDER BY created_at DESC" },
        ->(_m) { "New customers who registered today." }
      ],
      [
        /(?:how\s+many\s+)?customers?\s+(?:signed?\s+up|registered|joined)\s+(this\s+month|current\s+month)/i,
        ->(_m) { "SELECT COUNT(*) AS customer_signups FROM users WHERE role = 'buyer' AND date_trunc('month', created_at) = date_trunc('month', NOW())" },
        ->(_m) { "Number of new customers who signed up this month." }
      ],
      [
        /(?:how\s+many\s+)?customers?\s+(?:signed?\s+up|registered|joined)\s+(last\s+month|previous\s+month)/i,
        ->(_m) { "SELECT COUNT(*) AS customer_signups FROM users WHERE role = 'buyer' AND date_trunc('month', created_at) = date_trunc('month', NOW() - INTERVAL '1 month')" },
        ->(_m) { "Number of new customers who signed up last month." }
      ],
      [
        /(?:how\s+many\s+)?customers?\s+(?:signed?\s+up|registered|joined)\s+(last\s+|past\s+)?(\d+)\s+days?/i,
        ->(m) { n = m[2]; "SELECT COUNT(*) AS customer_signups FROM users WHERE role = 'buyer' AND created_at >= NOW() - INTERVAL '#{n} days'" },
        ->(m) { "Number of new customers who signed up in the last #{m[2]} days." }
      ],
      [
        /total\s+customers?|how\s+many\s+customers?|customer\s+count/i,
        ->(_m) { "SELECT COUNT(*) AS total_customers FROM users WHERE role = 'buyer'" },
        ->(_m) { "Total number of customers." }
      ],
      [
        /customers?\s+with\s+no\s+orders?|customers?\s+(?:who\s+)?never\s+ordered/i,
        ->(_m) { "SELECT u.id, u.name, u.email, u.created_at FROM users u LEFT JOIN orders o ON o.user_id = u.id WHERE u.role = 'buyer' AND o.id IS NULL ORDER BY u.created_at DESC" },
        ->(_m) { "Customers who registered but never placed an order." }
      ],
      [
        /monthly\s+(?:new\s+)?customers?|customers?\s+(?:by|per)\s+month|customer\s+growth/i,
        ->(_m) { "SELECT TO_CHAR(created_at, 'Month YYYY') AS month, COUNT(*) AS new_customers FROM users WHERE role = 'buyer' GROUP BY DATE_TRUNC('month', created_at), TO_CHAR(created_at, 'Month YYYY') ORDER BY DATE_TRUNC('month', created_at)" },
        ->(_m) { "Monthly new customer signups." }
      ],

      # ── Reviews ───────────────────────────────────────────────────────────────
      [
        /all\s+reviews?|show\s+(me\s+)?reviews?|list\s+reviews?/i,
        ->(_m) { "SELECT id, customer_name, rating, title, body, approved, created_at FROM reviews ORDER BY created_at DESC" },
        ->(_m) { "All customer reviews." }
      ],
      [
        /top\s+rated|highest\s+rated|best\s+reviews?/i,
        ->(_m) { "SELECT p.name, ROUND(AVG(r.rating)::numeric, 1) AS avg_rating, COUNT(*) AS review_count FROM reviews r JOIN products p ON p.id = r.product_id WHERE r.approved = true GROUP BY p.name ORDER BY avg_rating DESC" },
        ->(_m) { "Products ranked by average review rating." }
      ],
      [
        /pending\s+reviews?|unapproved\s+reviews?|reviews?\s+(not|un)approved/i,
        ->(_m) { "SELECT id, customer_name, rating, title, created_at FROM reviews WHERE approved = false ORDER BY created_at DESC" },
        ->(_m) { "Reviews awaiting approval." }
      ],
      [
        /approved\s+reviews?/i,
        ->(_m) { "SELECT id, customer_name, rating, title, created_at FROM reviews WHERE approved = true ORDER BY created_at DESC" },
        ->(_m) { "All approved reviews." }
      ],
      [
        /(?:(\d+)\s+)?star\s+reviews?|reviews?\s+with\s+(\d+)\s+(?:star|rating)/i,
        ->(m) { n = m[1] || m[2]; "SELECT id, customer_name, rating, title, body, created_at FROM reviews WHERE rating = #{n} ORDER BY created_at DESC" },
        ->(m) { n = m[1] || m[2]; "All #{n}-star reviews." }
      ],
      [
        /average\s+(?:review\s+)?rating|mean\s+rating|overall\s+rating/i,
        ->(_m) { "SELECT ROUND(AVG(rating)::numeric, 2) AS avg_rating, COUNT(*) AS total_reviews, COUNT(*) FILTER (WHERE approved = true) AS approved_reviews FROM reviews" },
        ->(_m) { "Average customer rating across all reviews." }
      ],
      [
        /negative\s+reviews?|bad\s+reviews?|low\s+(?:rated\s+)?reviews?/i,
        ->(_m) { "SELECT id, customer_name, rating, title, body, created_at FROM reviews WHERE rating <= 2 ORDER BY created_at DESC" },
        ->(_m) { "Negative reviews (2 stars or below)." }
      ],
      [
        /positive\s+reviews?|good\s+reviews?|high\s+(?:rated\s+)?reviews?/i,
        ->(_m) { "SELECT id, customer_name, rating, title, body, created_at FROM reviews WHERE rating >= 4 ORDER BY created_at DESC" },
        ->(_m) { "Positive reviews (4 stars or above)." }
      ],

      # ── Promotions ────────────────────────────────────────────────────────────
      [
        /active\s+promotions?|current\s+promotions?|promotions?\s+active/i,
        ->(_m) { "SELECT id, code, discount_type, discount_value, starts_at, ends_at FROM promotions WHERE active = true AND starts_at <= NOW() AND (ends_at IS NULL OR ends_at >= NOW())" },
        ->(_m) { "Currently active promotions." }
      ],
      [
        /all\s+promotions?|list\s+promotions?/i,
        ->(_m) { "SELECT id, code, discount_type, discount_value, active, starts_at, ends_at FROM promotions ORDER BY created_at DESC" },
        ->(_m) { "All promotions." }
      ],
      [
        /expired\s+promotions?|promotions?\s+expired/i,
        ->(_m) { "SELECT id, code, discount_type, discount_value, starts_at, ends_at FROM promotions WHERE ends_at IS NOT NULL AND ends_at < NOW() ORDER BY ends_at DESC" },
        ->(_m) { "Expired promotions." }
      ],
      [
        /most\s+used\s+(?:coupon|promo(?:tion)?)|popular\s+(?:coupon|promo(?:tion)?)/i,
        ->(_m) { "SELECT coupon_code, COUNT(*) AS times_used, SUM(discount_total) AS total_discount FROM orders WHERE coupon_code IS NOT NULL GROUP BY coupon_code ORDER BY times_used DESC LIMIT 10" },
        ->(_m) { "Most frequently used coupon codes." }
      ],

      # ── Categories ────────────────────────────────────────────────────────────
      [
        /all\s+categor(?:y|ies)|list\s+(?:of\s+)?categor(?:y|ies)|show\s+categor(?:y|ies)/i,
        ->(_m) { "SELECT id, name, slug, active, position FROM categories ORDER BY position ASC" },
        ->(_m) { "All product categories." }
      ],
      [
        /active\s+categor(?:y|ies)|categor(?:y|ies)\s+active/i,
        ->(_m) { "SELECT id, name, slug, position FROM categories WHERE active = true ORDER BY position ASC" },
        ->(_m) { "All active product categories." }
      ],
      [
        /(?:how\s+many\s+)?(?:products?\s+in\s+each\s+categor(?:y|ies)|categor(?:y|ies)\s+product\s+count|products?\s+(?:by|per)\s+categor(?:y|ies))/i,
        ->(_m) { "SELECT c.name AS category, COUNT(p.id) AS product_count, SUM(p.stock_quantity) AS total_stock FROM categories c LEFT JOIN products p ON p.category_id = c.id GROUP BY c.id, c.name ORDER BY product_count DESC" },
        ->(_m) { "Product count and stock per category." }
      ],

      # ── Testimonials ──────────────────────────────────────────────────────────
      [
        /all\s+testimonials?|list\s+(?:of\s+)?testimonials?|show\s+testimonials?/i,
        ->(_m) { "SELECT id, customer_name, role, quote, rating, featured, created_at FROM testimonials ORDER BY created_at DESC" },
        ->(_m) { "All customer testimonials." }
      ],
      [
        /featured\s+testimonials?|testimonials?\s+featured/i,
        ->(_m) { "SELECT id, customer_name, role, quote, rating FROM testimonials WHERE featured = true ORDER BY created_at DESC" },
        ->(_m) { "Featured customer testimonials." }
      ],
      [
        /testimonial\s+count|how\s+many\s+testimonials?/i,
        ->(_m) { "SELECT COUNT(*) AS total_testimonials, COUNT(*) FILTER (WHERE featured = true) AS featured FROM testimonials" },
        ->(_m) { "Total number of testimonials." }
      ],

      # ── Articles / Blog ───────────────────────────────────────────────────────
      [
        /all\s+articles?|list\s+(?:of\s+)?articles?|show\s+articles?|blog\s+posts?/i,
        ->(_m) { "SELECT id, title, slug, published, featured, created_at FROM articles ORDER BY created_at DESC" },
        ->(_m) { "All blog articles." }
      ],
      [
        /published\s+articles?|articles?\s+published/i,
        ->(_m) { "SELECT id, title, slug, featured, created_at FROM articles WHERE published = true ORDER BY created_at DESC" },
        ->(_m) { "All published articles." }
      ],
      [
        /featured\s+articles?|articles?\s+featured/i,
        ->(_m) { "SELECT id, title, slug, published, created_at FROM articles WHERE featured = true ORDER BY created_at DESC" },
        ->(_m) { "Featured articles." }
      ],
      [
        /unpublished\s+articles?|draft\s+articles?|articles?\s+not\s+published/i,
        ->(_m) { "SELECT id, title, slug, created_at FROM articles WHERE published = false ORDER BY created_at DESC" },
        ->(_m) { "Unpublished/draft articles." }
      ],
      [
        /article\s+count|how\s+many\s+articles?/i,
        ->(_m) { "SELECT COUNT(*) AS total_articles, COUNT(*) FILTER (WHERE published = true) AS published, COUNT(*) FILTER (WHERE published = false) AS drafts FROM articles" },
        ->(_m) { "Article count by publish status." }
      ],

      # ── FAQs ──────────────────────────────────────────────────────────────────
      [
        /all\s+faqs?|list\s+(?:of\s+)?faqs?|show\s+faqs?|frequently\s+asked/i,
        ->(_m) { "SELECT id, question, answer, position FROM faqs ORDER BY position ASC" },
        ->(_m) { "All FAQ entries." }
      ],
      [
        /faq\s+count|how\s+many\s+faqs?/i,
        ->(_m) { "SELECT COUNT(*) AS total_faqs FROM faqs" },
        ->(_m) { "Total number of FAQs." }
      ],

      # ── Newsletter ────────────────────────────────────────────────────────────
      [
        /newsletter\s+sign\s*ups?|email\s+sign\s*ups?|email\s+subscribers?/i,
        ->(_m) { "SELECT COUNT(*) AS total_signups, COUNT(*) FILTER (WHERE active = true) AS active_subscribers FROM newsletter_signups" },
        ->(_m) { "Total newsletter signups and active subscribers." }
      ],
      [
        /newsletter\s+growth|monthly\s+(?:newsletter|subscriber)\s+signups?/i,
        ->(_m) { "SELECT TO_CHAR(created_at, 'Month YYYY') AS month, COUNT(*) AS new_signups FROM newsletter_signups GROUP BY DATE_TRUNC('month', created_at), TO_CHAR(created_at, 'Month YYYY') ORDER BY DATE_TRUNC('month', created_at)" },
        ->(_m) { "Monthly newsletter signup growth." }
      ],

      # ── Misc / Summary ────────────────────────────────────────────────────────
      [
        /store\s+summary|dashboard\s+summary|business\s+overview|store\s+overview|overall\s+summary/i,
        ->(_m) { "SELECT (SELECT COUNT(*) FROM orders) AS total_orders, (SELECT ROUND(SUM(total)::numeric,2) FROM orders) AS total_revenue, (SELECT COUNT(*) FROM orders WHERE created_at::date = CURRENT_DATE) AS orders_today, (SELECT COUNT(*) FROM orders WHERE status IN (0,1,2,3)) AS open_orders, (SELECT COUNT(*) FROM products WHERE active = true) AS active_products, (SELECT COUNT(*) FROM products WHERE stock_quantity < 10) AS low_stock_products, (SELECT COUNT(*) FROM users WHERE role = 2) AS total_customers, (SELECT COUNT(*) FROM reviews WHERE approved = false) AS pending_reviews, (SELECT COUNT(*) FROM newsletter_signups WHERE active = true) AS newsletter_subscribers" },
        ->(_m) { "Full store overview: orders, revenue, products, customers, and more." }
      ],
      [
        /order\s+count|how\s+many\s+orders?|total\s+orders?|number\s+of\s+orders?/i,
        ->(_m) { "SELECT COUNT(*) AS order_count FROM orders" },
        ->(_m) { "Total number of orders." }
      ],
      [
        /content\s+summary|site\s+content|content\s+overview/i,
        ->(_m) { "SELECT (SELECT COUNT(*) FROM articles WHERE published = true) AS published_articles, (SELECT COUNT(*) FROM articles WHERE published = false) AS draft_articles, (SELECT COUNT(*) FROM faqs) AS total_faqs, (SELECT COUNT(*) FROM testimonials) AS testimonials, (SELECT COUNT(*) FROM newsletter_signups WHERE active = true) AS newsletter_subscribers, (SELECT COUNT(*) FROM categories WHERE active = true) AS active_categories" },
        ->(_m) { "Overview of site content: articles, FAQs, testimonials, and categories." }
      ],
      [
        /managers?\s+list|all\s+managers?|list\s+(?:of\s+)?managers?/i,
        ->(_m) { "SELECT id, name, email, active, registered_at, created_at FROM users WHERE role = 1 ORDER BY created_at DESC" },
        ->(_m) { "All manager accounts." }
      ],
      [
        /(?:how\s+many\s+)?managers?|manager\s+count/i,
        ->(_m) { "SELECT COUNT(*) AS total_managers, COUNT(*) FILTER (WHERE active = true) AS active_managers FROM users WHERE role = 1" },
        ->(_m) { "Total manager count." }
      ],
    ].freeze

    MONTH_MAP = {
      "jan" => 1, "january" => 1, "feb" => 2, "february" => 2,
      "mar" => 3, "march" => 3,   "apr" => 4, "april" => 4,
      "may" => 5, "jun" => 6,     "june" => 6, "jul" => 7, "july" => 7,
      "aug" => 8, "august" => 8,  "sep" => 9, "september" => 9,
      "oct" => 10, "october" => 10, "nov" => 11, "november" => 11,
      "dec" => 12, "december" => 12
    }.freeze

    def self.match(question)
      q = question.to_s.strip
      TEMPLATES.each do |regex, sql_fn, summary_fn|
        if (m = q.match(regex))
          sql     = sql_fn.call(m)
          summary = summary_fn.call(m)
          return Result.new(sql: sql, summary: summary, matched: true)
        end
      end
      Result.new(sql: nil, summary: nil, matched: false)
    end

    def self.month_number(name)
      MONTH_MAP[name.to_s.downcase] || 1
    end
  end
end
