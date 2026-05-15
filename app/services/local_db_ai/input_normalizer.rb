module LocalDbAi
  # Corrects common misspellings, broken English, and shorthand queries
  # before they reach the template engine or Ollama.
  # Zero dependencies — pure Ruby, runs in < 1ms.
  class InputNormalizer
    # Result carries the corrected text and whether a correction was made
    Result = Struct.new(:text, :corrected, :original, keyword_init: true)

    # ── Word-level corrections ─────────────────────────────────────────────────
    # Key = what the user typed (downcased), Value = canonical form
    WORD_MAP = {
      # Orders
      "ordr"         => "order",   "ordrs"       => "orders",
      "oder"         => "order",   "oders"       => "orders",
      "orderd"       => "ordered", "orderes"     => "orders",
      "oredr"        => "order",   "oredrs"      => "orders",
      "ordar"        => "order",   "ordars"      => "orders",
      "ordes"        => "orders",  "ordeer"      => "order",
      "orderss"      => "orders",  "odrer"       => "order",

      # Revenue / Sales
      "revenu"       => "revenue", "reveneu"     => "revenue",
      "revnue"       => "revenue", "revene"      => "revenue",
      "revenwe"      => "revenue", "revnew"      => "revenue",
      "reveniue"     => "revenue", "rvenue"      => "revenue",
      "reveue"       => "revenue", "revenuu"     => "revenue",
      "slaes"        => "sales",   "slae"        => "sale",
      "saels"        => "sales",   "sael"        => "sale",
      "sal"          => "sales",   "salesl"      => "sales",
      "totl"         => "total",   "totall"      => "total",
      "toatl"        => "total",   "ttal"        => "total",

      # Products
      "produt"       => "product", "produts"     => "products",
      "prdocut"      => "product", "prodcut"     => "product",
      "prduct"       => "product", "produc"      => "product",
      "pruduct"      => "product", "proudct"     => "product",
      "pruducts"     => "products","proudcts"    => "products",
      "prodects"     => "products","procuts"     => "products",
      "poduct"       => "product", "poducts"     => "products",
      "productes"    => "products","prodiuct"    => "product",
      "itmes"        => "items",   "itmees"      => "items",
      "itm"          => "item",    "iterm"       => "item",
      "ietm"         => "item",    "ietms"       => "items",

      # Stock / Inventory
      "stok"         => "stock",   "sttock"      => "stock",
      "stcok"        => "stock",   "stokc"       => "stock",
      "sotck"        => "stock",   "stck"        => "stock",
      "inventry"     => "inventory","inventroy"  => "inventory",
      "inventori"    => "inventory","inventary"  => "inventory",
      "inverntory"   => "inventory","invenory"   => "inventory",
      "lowstock"     => "low stock","lowstok"    => "low stock",

      # Customers
      "custmer"      => "customer","custmers"    => "customers",
      "cusotmer"     => "customer","cusotmers"   => "customers",
      "cutomer"      => "customer","cutomers"    => "customers",
      "custommer"    => "customer","custommers"  => "customers",
      "custmr"       => "customer","cusomer"     => "customer",
      "cusomers"     => "customers","costumer"   => "customer",
      "costumers"    => "customers","custumer"   => "customer",
      "custumers"    => "customers","cutsomer"   => "customer",

      # Time words
      "tday"         => "today",   "toady"       => "today",
      "todya"        => "today",   "todday"      => "today",
      "tod"          => "today",   "toay"        => "today",
      "tody"         => "today",
      "ystrday"      => "yesterday","ysterday"   => "yesterday",
      "yestrday"     => "yesterday","yesterdy"   => "yesterday",
      "ystrdy"       => "yesterday","ystday"     => "yesterday",
      "weekk"        => "week",    "weeke"       => "week",
      "weke"         => "week",    "mnth"        => "month",
      "montly"       => "monthly", "monthl"      => "monthly",
      "monthy"       => "monthly", "mothly"      => "monthly",
      "monly"        => "monthly", "monhtly"     => "monthly",
      "monlty"       => "monthly", "mthly"       => "monthly",
      "weeky"        => "weekly",  "weekley"     => "weekly",
      "dailly"       => "daily",   "dayly"       => "daily",
      "daly"         => "daily",   "daliy"       => "daily",
      "yealy"        => "yearly",  "yerly"       => "yearly",
      "yeraly"       => "yearly",  "anual"       => "annual",
      "annualy"      => "annually","anually"     => "annually",
      "lastt"        => "last",    "lsat"        => "last",
      "lst"          => "last",    "lats"        => "last",

      # Status words
      "deliverd"     => "delivered","delvered"   => "delivered",
      "delevered"    => "delivered","delivred"   => "delivered",
      "dlivered"     => "delivered","dlivrd"     => "delivered",
      "dlvrd"        => "delivered","dlvd"        => "delivered",
      "pendig"       => "pending", "pendng"      => "pending",
      "pening"       => "pending", "pnding"      => "pending",
      "pendign"      => "pending", "penidng"     => "pending",
      "canceld"      => "cancelled","cancled"    => "cancelled",
      "cancell"      => "cancelled","cancele"    => "cancelled",
      "cncelled"     => "cancelled","cnclled"    => "cancelled",
      "confimed"     => "confirmed","confrimed"  => "confirmed",
      "confirmd"     => "confirmed","comfirmed"  => "confirmed",
      "prepering"    => "preparing","preparng"   => "preparing",
      "prparing"     => "preparing","prepairng"  => "preparing",

      # Combo / bundle
      "comb"         => "combo",   "cmbo"        => "combo",
      "comob"        => "combo",   "ocmbo"       => "combo",
      "comboo"       => "combo",   "bundl"       => "bundle",
      "bundlee"      => "bundle",  "bndl"        => "bundle",
      "bundel"       => "bundle",

      # Review
      "reveiw"       => "review",  "reveiws"     => "reviews",
      "reivew"       => "review",  "reivews"     => "reviews",
      "reviwe"       => "review",  "revview"     => "review",
      "rveiw"        => "review",  "rviews"      => "reviews",
      "revu"         => "review",  "revews"      => "reviews",

      # Promotion / coupon
      "promtion"     => "promotion","promtions"  => "promotions",
      "promoion"     => "promotion","promoions"  => "promotions",
      "promation"    => "promotion","prmotions"  => "promotions",
      "pormotions"   => "promotions","couopn"    => "coupon",
      "copuon"       => "coupon",  "cupoon"      => "coupon",
      "couopns"      => "coupons", "copuons"     => "coupons",

      # Top / best
      "bst"          => "best",    "topp"        => "top",
      "tp"           => "top",

      # Show / list / give
      "sho"          => "show",    "shwo"        => "show",
      "lits"         => "list",    "lisr"        => "list",
      "giv"          => "give",    "gve"         => "give",
      "gime"         => "give me", "gibe"        => "give",
      "shw"          => "show",

      # General connectors
      "al"           => "all",     "alll"        => "all",
      "fo"           => "for",     "fro"         => "for",
      "fr"           => "for",     "wit"         => "with",
      "whit"         => "with",    "nd"          => "and",
      "adn"          => "and",     "andd"        => "and",
      "numbr"        => "number",  "nmber"       => "number",
      "numbre"       => "number",  "nmb"         => "number",
      "countt"       => "count",   "ocunt"       => "count",
      "cunt"         => "count",   "cnt"         => "count",

      # Organic / local / seasonal / featured
      "organik"      => "organic", "orgnic"      => "organic",
      "orgainc"      => "organic", "organiuc"    => "organic",
      "organc"       => "organic", "orgaanic"    => "organic",
      "seasnal"      => "seasonal","sesonal"     => "seasonal",
      "seasonl"      => "seasonal","seaonal"     => "seasonal",
      "feautred"     => "featured","fetaured"    => "featured",
      "featurd"      => "featured","feauterd"    => "featured",
      "locl"         => "local",   "locall"      => "local",

      # Summary
      "summry"       => "summary", "sumary"      => "summary",
      "summury"      => "summary", "summari"     => "summary",
      "overviw"      => "overview","overveiw"    => "overview",
      "overveiew"    => "overview",

      # Average
      "averge"       => "average", "averag"      => "average",
      "avrage"       => "average", "averg"       => "average",
      "avg"          => "average", "avv"         => "average",

      # Newsletter
      "newsleter"    => "newsletter","newletter"  => "newsletter",
      "newsltter"    => "newsletter","newslettr"  => "newsletter",

      # Article / blog / FAQ
      "artcle"       => "article", "artciles"    => "articles",
      "artile"       => "article", "artiles"     => "articles",
      "bolg"         => "blog",    "blgo"        => "blog",
      "faq"          => "faq",     "faqs"        => "faqs",

      # Testimonial
      "testimonal"   => "testimonial","tesitmonal"  => "testimonial",
      "testmonial"   => "testimonial","testimoinal" => "testimonial",
    }.freeze

    # ── Phrase-level normalizations (applied before word correction) ──────────
    # Handles shorthand, Hinglish patterns, collapsed phrases
    PHRASE_MAP = [
      # Collapsed words (no space)
      [/\blow\s*stok\b/i,            "low stock"],
      [/\btopproducts?\b/i,          "top products"],
      [/\ballorders?\b/i,            "all orders"],
      [/\btotalrevenue\b/i,          "total revenue"],
      [/\bdailyorders?\b/i,          "daily orders"],
      [/\bweeklyorders?\b/i,         "weekly orders"],
      [/\bmonthlyrevenue\b/i,        "monthly revenue"],
      [/\bdailyrevenue\b/i,          "daily revenue"],

      # Hinglish / mixed language shortcuts
      [/\baaj\s*(k[ae])?\s*orders?\b/i,          "orders today"],
      [/\bkal\s*(k[ae])?\s*orders?\b/i,           "orders yesterday"],
      [/\bkitne\s*orders?\b/i,                    "how many orders"],
      [/\bkitna\s*revenue\b/i,                    "total revenue"],
      [/\bsab\s*(products?|saman)\b/i,            "all products"],
      [/\bkam\s*stock\b/i,                        "low stock"],
      [/\bkm\s*stok\b/i,                          "low stock"],
      [/\bsale\s+aaj\b/i,                         "revenue today"],
      [/\bbikri\b/i,                              "revenue"],
      [/\bsaman\b/i,                              "products"],
      [/\bpaise\b/i,                              "revenue"],
      [/\bkharidari\b/i,                          "orders"],
      [/\bgraahak\b/i,                            "customers"],
      [/\bkharidaar\b/i,                          "customers"],
      [/\bpending\s+kya\s+hai\b/i,               "pending orders"],
      [/\bkitne\s+(customer|graahak)\b/i,         "how many customers"],
      [/\bstock\s+kya\s+hai\b/i,                  "all products"],
      [/\bkitna\s+stock\b/i,                      "inventory value"],

      # Number words → digits
      [/\bone\b/i,   "1"],
      [/\btwo\b/i,   "2"],
      [/\bthree\b/i, "3"],
      [/\bfour\b/i,  "4"],
      [/\bfive\b/i,  "5"],
      [/\bsix\b/i,   "6"],
      [/\bseven\b/i, "7"],
      [/\beight\b/i, "8"],
      [/\bnine\b/i,  "9"],
      [/\bten\b/i,   "10"],

      # Common shorthand patterns
      [/\borders?\s+4\s+today\b/i,               "orders today"],
      [/\borders?\s+2day\b/i,                     "orders today"],
      [/\br[ev]+enue\s+4\s+today\b/i,            "revenue today"],
      [/\bplz\b/i,                                "please"],
      [/\bpls\b/i,                                "please"],
      [/\bwht\b/i,                                "what"],
      [/\bhw\b/i,                                 "how"],
      [/\bcnt\b/i,                                "count"],
      [/\bno\.\s*of\b/i,                          "number of"],
      [/\b#\s*of\b/i,                             "number of"],
      [/\blst\s+(\d+)\s+days?\b/i,               'last \1 days'],

      # Missing spaces between quantity and unit
      [/\borders?\s*2day\b/i,              "orders today"],
      [/(\d+)days?\b/i,     '\1 days'],
      [/(\d+)weeks?\b/i,    '\1 weeks'],
      [/(\d+)months?\b/i,   '\1 months'],
      [/(\d+)hours?\b/i,    '\1 hours'],
      [/(\d+)hrs?\b/i,      '\1 hours'],
    ].freeze

    def self.normalize(question)
      original = question.to_s.strip
      text = original.dup

      # Step 1: phrase-level replacements
      PHRASE_MAP.each do |pattern, replacement|
        text = text.gsub(pattern, replacement)
      end

      # Step 2: word-level spelling correction
      corrected_words = text.split(/(\s+)/).map do |token|
        # preserve whitespace tokens
        next token if token.match?(/\A\s+\z/)
        # only correct pure word tokens (letters only, 3+ chars to avoid false positives)
        lower = token.downcase.gsub(/[^a-z]/, "")
        if lower.length >= 3 && WORD_MAP.key?(lower)
          # preserve capitalisation of first letter if original was capitalised
          corrected = WORD_MAP[lower]
          token[0] == token[0].upcase ? corrected.capitalize : corrected
        else
          token
        end
      end.join

      # Step 3: clean up extra spaces
      corrected_text = corrected_words.gsub(/\s{2,}/, " ").strip

      was_corrected = corrected_text.downcase != original.downcase
      Result.new(text: corrected_text, corrected: was_corrected, original: original)
    end
  end
end
