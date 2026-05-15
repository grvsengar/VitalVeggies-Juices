module LocalDbAi
  class ConversationHandler
    PATTERNS = [
      # ── Greetings ─────────────────────────────────────────────────────────────
      {
        regex: /\A(hi+|hello+|hey+|good\s*(morning|afternoon|evening|day|night)|howdy|greetings|sup|what'?s\s+up)[!?.\s]*\z/i,
        reply: "Hey! I'm your Vital Veggies data analyst. Ask me anything about orders, revenue, products, customers, or inventory."
      },

      # ── Acknowledgements ──────────────────────────────────────────────────────
      {
        regex: /\A(thanks?|thank\s*you|cheers|great|awesome|perfect|nice\s+one|cool|got\s*it|okay|ok|alright|sounds\s+good|noted|got\s+it)[!?.\s]*\z/i,
        reply: "You're welcome! Ask me another question anytime."
      },
      {
        regex: /\A(good|bad|okay|fine|nice|cool|wow|great|amazing|excellent|nice|lovely|wonderful|brilliant)[!?.\s]*\z/i,
        reply: "Glad to hear it! What would you like to query next?"
      },

      # ── How are you / small talk ───────────────────────────────────────────────
      {
        regex: /how\s+are\s+you|how('?re)\s+you|you\s+okay|how\s+do\s+you\s+do|how'?s\s+it\s+going/i,
        reply: "Doing great and ready to query your data! What would you like to know?"
      },
      {
        regex: /good\s+to\s+meet\s+you|nice\s+to\s+meet\s+you|pleased\s+to\s+meet/i,
        reply: "Nice to meet you too! I'm your store's AI analyst — ask me anything about your data."
      },

      # ── Identity ──────────────────────────────────────────────────────────────
      {
        regex: /who\s+are\s+you|what\s+are\s+you|introduce\s+yourself|tell\s+me\s+about\s+yourself|your\s+name/i,
        reply: "I'm the AI analyst built into Vital Veggies Manager. I understand plain English and turn it into live database queries — orders, revenue, products, customers, reviews, and more."
      },
      {
        regex: /are\s+you\s+(a\s+)?(human|person|bot|robot|ai|chatgpt|gpt|claude|ollama)/i,
        reply: "I'm an AI assistant powered by a local language model running entirely on your server — your data never leaves your infrastructure."
      },
      {
        regex: /who\s+(made|built|created|developed)\s+you|who\s+is\s+your\s+(creator|developer|maker)/i,
        reply: "I was built into Vital Veggies Manager by your development team. I run on Ollama — a local AI model — so everything stays private."
      },
      {
        regex: /what\s+(model|llm|ai\s+model)\s+are\s+you\s+using|which\s+(model|llm)\s+(is|are)\s+(this|you)/i,
        reply: "I'm running on Ollama with a local language model on your own server. Your data never leaves your infrastructure."
      },

      # ── Capabilities / Help ───────────────────────────────────────────────────
      {
        regex: /what\s+can\s+you\s+do|help(\s+me)?|what\s+(should|can)\s+i\s+ask|capabilities|features|what\s+do\s+you\s+know|how\s+do\s+(i\s+use\s+)?you/i,
        reply: "Here's what I can answer:\n\n• **Orders** — all orders, today/yesterday/last N hours/days, this week/month, by status (pending → confirmed → preparing → out for delivery → delivered → cancelled), open orders, by customer name, with coupon/discount, highest value, daily/weekly breakdown\n• **Revenue** — total, today/yesterday, this week/month, last N days, monthly/weekly/daily breakdown, by product, discount totals, delivery fees collected\n• **Products** — all products, low/zero stock, top sellers, least selling, by price range, organic/local/seasonal/featured, juice/fruit/vegetable/combo, inactive, never sold, inventory value, product type breakdown\n• **Combo & Bulk** — combo items, combo orders/revenue, low-stock combos, bulk orders, bulk items\n• **Customers** — all customers, top spenders, repeat/loyal customers, never ordered, new signups, monthly growth\n• **Reviews** — all reviews, pending approval, average rating, positive/negative, by star rating\n• **Promotions** — active, expired, most used coupons\n• **Store Summary** — full dashboard overview\n• **Combined queries** — ask multiple things at once, e.g. \"monthly revenue and low stock products\"\n\nJust ask in plain English — I'll handle the SQL!"
      },
      {
        regex: /what\s+tables?|what\s+data\s+do\s+you\s+have|what\s+database|what\s+can\s+you\s+access/i,
        reply: "I have read-only access to these tables:\n\n• **orders** — all customer orders with status, totals, dates\n• **order_items** — individual items within each order\n• **products** — your product catalog with stock, price, type, attributes\n• **users** — customers and managers\n• **reviews** — customer product reviews\n• **promotions** — coupon codes and discounts\n• **newsletter_signups** — email subscribers\n• **categories** — product categories\n• **testimonials** — customer testimonials\n• **articles** — blog/content articles\n• **faqs** — FAQ entries\n\nI can query all of these in plain English!"
      },
      {
        regex: /how\s+do\s+i\s+(search|find|look\s+up|query)\s+(.+)/i,
        reply: "Just type your question naturally! For example:\n• \"Orders from last 7 days\"\n• \"Products with low stock\"\n• \"Top 5 customers by spend\"\n• \"Monthly revenue this year\"\nI'll convert it to SQL and show you the results."
      },

      # ── Vague / unclear intent ─────────────────────────────────────────────────
      {
        regex: /\A(i\s+want\s+to\s+know(\s+something)?|tell\s+me\s+something|show\s+me\s+something|something|anything|idk|not\s+sure|hmm+|umm+|uh+|er+|test|hello\s+test|test\s+query)\z/i,
        reply: "Sure! What specifically would you like to know? For example:\n• \"Orders last 7 days\"\n• \"Total revenue this month\"\n• \"Top 5 best-selling products\"\n• \"Low stock products\"\n• \"Store summary\""
      },
      {
        regex: /\A(what|show|tell|give|get|fetch|find|list|display)\s*\??\.?\z/i,
        reply: "What would you like to see? You can ask about orders, revenue, products, customers, reviews, or promotions. Type \"help\" for the full list."
      },

      # ── Jokes / fun ───────────────────────────────────────────────────────────
      {
        regex: /tell\s+(me\s+)?a\s+joke|make\s+me\s+laugh|funny|say\s+something\s+funny/i,
        reply: "Why did the mango go to the manager's dashboard? Because it heard the numbers were juicy! 🥭\n\nNow ask me something about your store data!"
      },
      {
        regex: /sing\s+(me\s+)?a\s+song|play\s+(some\s+)?music/i,
        reply: "🎵 Revenue up, stock is right, orders flowing day and night... 🎵\n\nOkay, music isn't my forte — but data analysis is! What would you like to know?"
      },

      # ══════════════════════════════════════════════════════════════════════════
      # Questions we CANNOT answer — catch broadly, respond like a human
      # ══════════════════════════════════════════════════════════════════════════

      # ── Mandi / market / live prices ──────────────────────────────────────────
      # Catches: "today's mandi or market price for tomatoes", "mandi rate potato",
      #          "what is the price of onion today", "how much does tomato cost now",
      #          "current vegetable prices", "wholesale rate for carrots"
      {
        regex: /mandi|wholesale\s+rate|market\s+(price|rate)|live\s+(price|rate)|current\s+(price|rate)\s+(of|for)\s+(vegetable|fruit|produce|tomato|potato|onion|carrot|spinach|ginger|garlic)|(price|rate|cost)\s+(of|for)\s+(tomato|potato|onion|carrot|spinach|ginger|garlic|cabbage|cauliflower|brinjal|capsicum|cucumber|pumpkin|corn|beetroot|radish|mushroom|bean|pea|lemon|lime|orange|banana|mango|apple|grape|papaya|watermelon|guava|pomegranate)|(tomato|potato|onion|carrot|spinach|ginger|garlic|vegetable|fruit|produce)\s+(price|rate|cost)\s*(today|now|currently|aaj|this\s+week)?|how\s+much\s+(does|is|are)\s+(tomato|potato|onion|vegetable|fruit)|price\s+today|rate\s+today|today.{0,15}price|price.{0,15}today/i,
        reply: "I don't have live market or mandi prices — those change daily and aren't stored in your database.\n\nWhat I *can* show you is your store's own pricing. Try:\n• \"Vegetable products\" — all veggies with your set prices\n• \"All products\" — full catalog with current prices\n• \"Most expensive products\" or \"Cheapest products\""
      },

      # ── Predicting / forecasting ───────────────────────────────────────────────
      # Catches: "predict next month revenue", "what will sales be next week",
      #          "forecast for next quarter", "expected growth next year"
      {
        regex: /predict|forecast|projection|next\s+(month|week|quarter|year|season)|future\s+(revenue|orders|sales|demand|growth)|will\s+(revenue|orders|sales|stock)\s+(be|grow|increase|drop)|expected\s+(revenue|orders|sales|growth|demand)|how\s+much\s+will\s+(we|i)\s+(make|earn|sell)/i,
        reply: "I can only analyse what has already happened — I can't predict the future.\n\nBut I can show you trends to help you plan:\n• \"Monthly revenue\" — see how revenue is growing\n• \"Weekly orders\" — spot order patterns\n• \"Top 5 products\" — know what to stock more of"
      },

      # ── Comparing periods ─────────────────────────────────────────────────────
      # Catches: "compare this month vs last month", "month over month growth",
      #          "how does this week compare to last week", "year over year"
      {
        regex: /compar(e|ing|ison)\s+(this|last|current|previous)\s+(month|week|year|quarter)|vs\.?\s+(last|previous|prior)\s+(month|week|year)|month\s+over\s+month|week\s+over\s+week|year\s+over\s+year|growth\s+rate|(this|last)\s+(month|week)\s+(vs|versus|compared\s+to|against)\s+(last|this|previous)\s+(month|week)/i,
        reply: "I don't have a built-in period comparison yet, but here's how to do it yourself:\n\n1. Ask \"Revenue this month\" → note the number\n2. Ask \"Revenue last month\" → compare\n\nOr ask \"Monthly revenue\" for a full month-by-month table you can compare at a glance."
      },

      # ── Weather / external environment ────────────────────────────────────────
      {
        regex: /weather|temperature|rain(fall)?|humidity|season\s+forecast|climate|will\s+it\s+rain|hot\s+today|cold\s+today/i,
        reply: "I don't have access to weather data — I only work with your store's internal database.\n\nIf you're thinking about seasonal demand, try:\n• \"Seasonal products\" — what's marked seasonal in your catalog\n• \"Monthly revenue\" — see which months sell more"
      },

      # ── Competitor / external market ─────────────────────────────────────────
      {
        regex: /competitor|competition|rival|other\s+store|blinkit|zepto|bigbasket|swiggy\s+instamart|dunzo|market\s+share|industry\s+(data|average|benchmark)|how\s+(am|are)\s+(i|we)\s+(doing\s+)?(compared|vs|versus)\s+(to\s+)?(others|competition|market)/i,
        reply: "I only have access to your store's internal data — no competitor or external market data.\n\nFor your own performance:\n• \"Store summary\" — full business overview\n• \"Monthly revenue\" — your growth over time\n• \"Top 5 products\" — your best sellers"
      },

      # ── Sending messages / notifications ─────────────────────────────────────
      # Catches: "send email to customers", "notify pending order customers",
      #          "message all buyers", "send whatsapp"
      {
        regex: /send\s+(an?\s+)?(email|message|sms|text|notification|alert|whatsapp|push\s+notification)|email\s+(all\s+)?(customers?|users?|buyers?)|notify\s+(customers?|users?|buyers?)|message\s+(customers?|users?|buyers?)|blast\s+(email|message|sms)/i,
        reply: "I'm a read-only analytics tool — I can't send emails, messages, or notifications.\n\nFor customer communications, use the Orders or Customer section in Manager.\n\nI can help you *find* who to reach:\n• \"Customers with no orders\" — re-engagement targets\n• \"Pending orders\" — customers still waiting\n• \"Top customers\" — VIPs to reward"
      },

      # ── Updating / editing / deleting data ───────────────────────────────────
      # Catches: "update order status", "change price of product", "delete order",
      #          "mark as delivered", "cancel order #123", "edit product"
      {
        regex: /\b(update|change|edit|modify|set|mark|flag)\b.{0,30}\b(order|product|price|stock|status|customer|record|inventory)\b|\b(delete|remove|archive|cancel)\b.{0,20}\b(order|product|customer|record)\b|mark\s+(as\s+)?(delivered|cancelled|paid|confirmed|done)|set\s+(status|price|stock)\s+(to|as)/i,
        reply: "I'm a read-only analytics tool — I can't update, edit, delete, or change any data.\n\nTo manage your store:\n• **Orders** — go to the Orders section in Manager\n• **Products** — go to the Products section\n• **Inventory** — go to the Inventory section\n\nI can help you *find* what you need first:\n• \"Pending orders\" — orders to action\n• \"Low stock products\" — products to update"
      },

      # ── Creating / adding new records ─────────────────────────────────────────
      {
        regex: /\b(create|add|new|insert|make)\b.{0,20}\b(order|product|coupon|promo|promotion|customer|user|category|article|faq)\b|place\s+(a\s+|an?\s+)?order|new\s+order|add\s+to\s+(stock|inventory)/i,
        reply: "I can only read data, not create it.\n\nTo add or create records, use the relevant section in Manager:\n• **New product** → Products section\n• **New promotion** → Promotions section\n• **Place order** → Orders section\n\nI can check what already exists — try \"all products\" or \"active promotions\"."
      },

      # ── Payment gateway / refunds / invoices ──────────────────────────────────
      {
        regex: /payment\s+(gateway|failed|error|issue|link)|razorpay|stripe|paytm|upi\s+(payment|id)|invoice\s+(generate|send|download|create)|refund\s+(status|process|initiate|request)|billing\s+(details|info|history)|payment\s+not\s+(received|done|completed)/i,
        reply: "I don't have access to payment gateway details or refund processing.\n\nYour store uses Cash on Delivery, so all orders show payment_status as 'pending' until manually updated.\n\nFor financial analytics I *can* help with:\n• \"Total revenue\" — all-time earnings\n• \"Orders with coupon\" — discounted orders\n• \"Monthly revenue\" — earnings over time"
      },

      # ── GST / Tax / Compliance ────────────────────────────────────────────────
      {
        regex: /\bgst\b|tax\s+(report|calculation|invoice|amount|filing|return)|tds|hsn\s+code|tax\s+compliance|income\s+tax|tax\s+paid|taxable\s+(income|amount)/i,
        reply: "I don't have GST or tax breakdown data — orders store total amounts but not itemised tax components.\n\nFor GST filing, export your orders data:\n• Run \"All orders\" or \"Monthly revenue\"\n• Use the Excel/CSV export button\n• Process in your accounting tool (Tally, Zoho Books, etc.)"
      },

      # ── Restock / supplier / purchase orders ─────────────────────────────────
      {
        regex: /restock|reorder\s+(stock|inventory|products?)|place\s+(a\s+)?purchase\s+order|order\s+from\s+(supplier|vendor|wholesaler)|buy\s+(more\s+)?(stock|inventory|products?)|procurement|vendor\s+(contact|details|list)/i,
        reply: "I can't place supplier orders or manage procurement — I only analyse your existing inventory data.\n\nTo plan your restocking:\n• \"Low stock products\" — items below 10 units\n• \"Out of stock products\" — items at zero\n• \"Inventory value\" — total worth of current stock\n• \"Never sold products\" — items you might not need to restock"
      },

      # ── Delivery tracking (real-time) ─────────────────────────────────────────
      {
        regex: /track\s+(order|delivery|shipment|package)|where\s+is\s+(my\s+|the\s+|this\s+)?order|delivery\s+(location|tracking|map|status\s+of\s+order\s+#)|estimated\s+(delivery|arrival|time)|when\s+will\s+(order|delivery)\s+(arrive|reach|come)/i,
        reply: "I don't have real-time GPS or delivery tracking — I can only show order statuses from your database.\n\nTo check delivery status:\n• \"Out for delivery\" — all orders currently with delivery staff\n• \"Orders by customer [name]\" — find a specific customer's order\n• \"Delivered orders\" — completed deliveries"
      },

      # ── Profit margin / cost price / supplier pricing ─────────────────────────
      {
        regex: /profit\s+(margin|percentage|per\s+order|per\s+product)|cost\s+(price|of\s+goods)|cogs|gross\s+(profit|margin)|net\s+(profit|margin)|how\s+much\s+(profit|margin)\s+(am\s+i|are\s+we)\s+making|markup/i,
        reply: "I don't have cost price or supplier pricing data — only your customer-facing sale prices.\n\nWithout cost data, I can't calculate margins. But I can show you revenue:\n• \"Revenue by product\" — which products earn most\n• \"Top 5 products\" — best sellers\n• \"Total revenue\" — overall earnings"
      },

      # ── Staff / HR / internal team ────────────────────────────────────────────
      {
        regex: /staff|employee|hr\s+(data|report|records?)|salary|attendance|work(ing)?\s+(hours?|shift)|payroll|leave\s+(request|balance)|team\s+performance|delivery\s+(boy|agent|partner|staff)\s+(list|count|performance)/i,
        reply: "I don't have staff, HR, or payroll data — only customer and manager accounts are in the database.\n\nI can show manager accounts: try \"all managers\" to see your team's logins."
      },

      # ── Social media / ads / external marketing ───────────────────────────────
      {
        regex: /social\s+media|instagram|facebook|twitter|youtube|tiktok|whatsapp\s+(business|marketing)|google\s+(ads|analytics)|campaign\s+(performance|analytics|results|clicks)|ad\s+(spend|performance|clicks|impressions|cpc|cpm)|roas|click\s+through/i,
        reply: "I don't have access to social media or advertising data — I only work with your store's internal database.\n\nFor marketing insights from your own data:\n• \"Orders with coupon\" — see which promo codes drive orders\n• \"Most used coupons\" — your best-performing offers\n• \"Monthly new customers\" — customer acquisition trend"
      },

      # ── Recipe / nutrition / health content ───────────────────────────────────
      {
        regex: /recipe|nutrition(al)?|calorie|protein|vitamin|mineral|how\s+(healthy|good)\s+is|health\s+benefit|ingredient\s+for|what\s+to\s+(cook|make|eat)|diet\s+(plan|chart)|nutrition\s+value\s+of/i,
        reply: "I don't have nutritional or recipe data — I only know your product catalog (name, price, stock, type).\n\nFor product info, try:\n• \"All products\" — full catalog\n• \"Organic products\" — all organic items\n• \"Vegetable products\" or \"Fruit products\""
      },

      # ── Business strategy / advice ────────────────────────────────────────────
      {
        regex: /what\s+should\s+i\s+(do|sell|focus\s+on|improve|change|stock)|how\s+(can|should|do)\s+i\s+(grow|increase|improve|boost|fix)\s+(sales|revenue|orders|profit|business)|give\s+me\s+(advice|suggestions?|recommendations?|tips?)|business\s+(advice|strategy|plan|tips)|what'?s?\s+(wrong|the\s+problem)\s+with\s+my\s+(store|business|sales)/i,
        reply: "I'm an analytics tool — I surface data, but the strategy is yours to decide!\n\nHere's data that can inform your decisions:\n• \"Least selling products\" — what's not moving\n• \"Top customers\" — who to reward\n• \"Customers with no orders\" — who to re-engage\n• \"Monthly revenue\" — growth trend\n• \"Low stock products\" — what needs restocking"
      },

      # ── Order lookup by specific number ───────────────────────────────────────
      {
        regex: /order\s+(number|#|no\.?|id)\s*[:\-]?\s*([A-Z0-9\-]{3,})|#[A-Z0-9\-]{3,}/i,
        reply: "Looking up a specific order number is best done in the Orders section in Manager where you can see full details.\n\nI work best with bulk queries. I can help with:\n• \"Orders by customer [name]\" — find all orders for someone\n• \"Pending orders\" or \"Delivered orders\" — by status"
      },

      # ── Glossary / definitions ────────────────────────────────────────────────
      {
        regex: /what\s+(is|are|does)\s+(a\s+)?(combo|bundle|product\s+kind|product\s+type|bulk|sku|slug|order\s+status|payment\s+status)\s+(mean|is)?/i,
        reply: "Here's a quick glossary:\n\n• **Combo** — a bundled product (juice + fruit pack, etc.)\n• **SKU** — Stock Keeping Unit, a unique product code\n• **Bulk order** — an order with 5 or more total items\n• **Low stock** — products with fewer than 10 units\n• **Product types** — Juice, Fruit, Vegetable, Combo\n• **Order status** — Pending → Confirmed → Preparing → Out for Delivery → Delivered (or Cancelled)"
      },

      # ── Profanity guard ───────────────────────────────────────────────────────
      {
        regex: /\b(fuck|shit|bastard|bitch|asshole|motherfucker|wtf|damn\s+you|idiot|moron|stupid\s+(app|tool|thing)|useless\s+(app|tool|thing))\b/i,
        reply: "Let's keep it professional! I'm here to help with your store analytics. What data would you like to explore?"
      },

      # ── Gibberish / too short ─────────────────────────────────────────────────
      {
        regex: /\A[^a-zA-Z0-9\s]{3,}\z/i,
        reply: "I didn't quite understand that. Try asking about orders, revenue, products, or customers — or type \"help\" to see everything I can do."
      },
    ].freeze

    def self.handle(question)
      q = question.to_s.strip
      PATTERNS.each do |p|
        return p[:reply] if q.match?(p[:regex])
      end
      nil
    end
  end
end
