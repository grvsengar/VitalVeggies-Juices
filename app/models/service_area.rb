class ServiceArea
  AREAS = {
    "indiranagar" => {
      name: "Indiranagar",
      intro: "Fast produce delivery for apartment households, office teams, and fitness-first buyers around 100 Feet Road and HAL 2nd Stage.",
      delivery_note: "Indiranagar orders are a strong fit for same-day juice restocks, fruit baskets, and quick weekday vegetable top-ups.",
      landmarks: [ "100 Feet Road", "CMH Road", "HAL 2nd Stage" ],
      nearby_area_slugs: %w[domlur ulsoor cv-raman-nagar]
    },
    "domlur" => {
      name: "Domlur",
      intro: "Neighborhood-friendly delivery for residential blocks, office corridors, and recurring produce orders near the Inner Ring Road stretch.",
      delivery_note: "Domlur customers often use the store for compact family baskets, office fruit drops, and evening grocery recovery orders.",
      landmarks: [ "Inner Ring Road", "Old Airport Road", "Domlur Flyover" ],
      nearby_area_slugs: %w[indiranagar ulsoor koramangala]
    },
    "ulsoor" => {
      name: "Ulsoor",
      intro: "Fresh juice, fruit, and vegetable delivery tuned for dense residential pockets and quick-turn daily shopping close to the lake and MG Road side.",
      delivery_note: "Ulsoor orders typically combine quick fruit baskets with local vegetables and smaller same-day delivery windows.",
      landmarks: [ "Ulsoor Lake", "Old Madras Road", "MG Road edge" ],
      nearby_area_slugs: %w[indiranagar domlur mg-road]
    },
    "cv-raman-nagar" => {
      name: "CV Raman Nagar",
      intro: "Reliable delivery coverage for gated communities and family buyers who want simple online ordering for vegetables, fruits, and seasonal combos.",
      delivery_note: "CV Raman Nagar orders skew toward weekly household baskets and recurring fresh-juice add-ons.",
      landmarks: [ "Bagmane Tech Park", "DRDO Township", "Kaggadasapura edge" ],
      nearby_area_slugs: %w[indiranagar domlur kaggadasapura]
    },
    "koramangala" => {
      name: "Koramangala",
      intro: "A good match for startup offices, shared apartments, and repeat weekly buyers looking for better produce quality and clean checkout flows.",
      delivery_note: "Koramangala demand is strongest for office fruit trays, juice packs, and family-ready produce combos.",
      landmarks: [ "80 Feet Road", "Forum South Bengaluru belt", "Koramangala 4th Block" ],
      nearby_area_slugs: %w[domlur hsr-layout btm-layout]
    }
  }.freeze

  attr_reader :slug, :name, :intro, :delivery_note, :landmarks, :nearby_area_slugs

  def self.all
    AREAS.map { |slug, attributes| new(slug, attributes) }
  end

  def self.find(slug)
    attributes = AREAS[slug.to_s]
    return if attributes.blank?

    new(slug, attributes)
  end

  def initialize(slug, attributes)
    @slug = slug
    @name = attributes.fetch(:name)
    @intro = attributes.fetch(:intro)
    @delivery_note = attributes.fetch(:delivery_note)
    @landmarks = attributes.fetch(:landmarks)
    @nearby_area_slugs = attributes.fetch(:nearby_area_slugs)
  end

  def city
    "Bengaluru"
  end

  def region
    "Karnataka"
  end

  def full_name
    "#{name}, #{city}"
  end

  def hero_title
    "Fresh juice, fruit, and vegetable delivery in #{full_name}"
  end

  def meta_title
    "#{name} delivery for juices, fruits, and vegetables"
  end

  def meta_description
    "Order fresh juices, fruit baskets, and vegetable packs in #{full_name} from Vital Veggies & Juices. Same-day neighborhood delivery, seasonal produce, and easy online checkout."
  end

  def nearby_areas
    nearby_area_slugs.filter_map { |area_slug| self.class.find(area_slug) }
  end
end
