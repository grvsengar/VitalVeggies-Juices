class Avo::Fields::CarrierWaveImageField < Avo::Fields::BaseField
  attr_reader :accept, :height, :radius, :width, :link_to_record

  def initialize(id, **args, &block)
    super(id, **args, &block)

    @accept = args[:accept] || "image/png,image/jpeg,image/webp,image/gif"
    @height = args[:height] || 48
    @width = args[:width] || 72
    @radius = args[:radius] || 8
    @link_to_record = args[:link_to_record].present? ? args[:link_to_record] : false
  end

  def image_url
    upload = value
    return if upload.blank?

    upload.respond_to?(:url) ? upload.url : upload.to_s
  end

  def fill_field(record, key, value, params)
    return record if value.blank?

    record.public_send(:"#{key}=", value)
    record
  end
end
