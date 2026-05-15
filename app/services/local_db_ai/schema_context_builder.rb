module LocalDbAi
  class SchemaContextBuilder
    def build
      <<~SCHEMA
        TABLES:
        orders(id,order_number,user_id,customer_name,email,phone,status,subtotal,discount_total,delivery_fee,total,payment_method,payment_status,coupon_code,paid_at,created_at)
        order_items(id,order_id,product_id,product_name,quantity,unit_price,line_total)
        products(id,name,sku,price,stock_quantity,active,featured,organic,local,seasonal,product_kind[0=juice,1=fruit,2=vegetable,3=combo])
        users(id,name,email,role[0=admin,1=manager,2=buyer],active,created_at)
        reviews(id,product_id,customer_name,title,body,rating,approved,created_at)
        promotions(id,code,discount_type,discount_value,active,starts_at,ends_at)
        newsletter_signups(id,email,active,created_at)
        categories(id,name,slug,active,position)
        testimonials(id,customer_name,role,quote,rating,featured,created_at)
        articles(id,title,slug,published,featured,created_at)
        faqs(id,question,answer,position)
      SCHEMA
    end
  end
end
