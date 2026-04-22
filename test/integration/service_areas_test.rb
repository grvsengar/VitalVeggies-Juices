require "test_helper"

class ServiceAreasTest < ActionDispatch::IntegrationTest
  setup do
    category = Category.create!(
      name: "Fresh Juices",
      description: "Daily pressed juices",
      position: 1,
      active: true
    )

    Product.create!(
      category: category,
      name: "Green Glow Juice",
      sku: "VVJ-SEO-1001",
      description: "Fresh green juice for local delivery pages.",
      ingredients: "Spinach, apple, cucumber",
      price: 95,
      stock_quantity: 8,
      featured: true,
      active: true,
      product_kind: :juice
    )

    Article.create!(
      title: "Neighborhood produce delivery guide",
      excerpt: "Local delivery content for Bengaluru shoppers.",
      body: "Fresh local content makes service-area pages more useful and less repetitive.",
      published: true,
      published_on: Date.current,
      featured: true
    )
  end

  test "shows a service area landing page with geo metadata" do
    get location_page_path("indiranagar")

    assert_response :success
    assert_select "title", /Indiranagar delivery/
    assert_select "h1", /Indiranagar, Bengaluru/
    assert_select "link[rel='canonical']", 1
    assert_select "a[href='/products']", text: "Shop products"
    assert_includes @response.body, "/service-areas/indiranagar"
    assert_includes @response.body, "Indiranagar, Bengaluru"
  end

  test "returns 404 for an unknown service area" do
    get location_page_path("unknown-neighborhood")

    assert_response :missing
  end

  test "delivery page links to service area pages" do
    get delivery_path

    assert_response :success
    assert_select "a[href='/service-areas/indiranagar']", text: /Explore Indiranagar/
    assert_select "a[href='/service-areas/koramangala']", text: /Explore Koramangala/
  end
end
