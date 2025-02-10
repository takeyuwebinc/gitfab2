module StripGps
  extend ActiveSupport::Concern

  included do
    process :strip_gps, if: :jpeg?
  end

  def strip_gps
    cache_stored_file! if !cached?
    exif = MiniExiftool.new(current_path)
    exif.GPSLatitude = nil
    exif.GPSLongitude = nil
    exif.GPSAltitude = nil
    exif.save
  end

  def jpeg?(carrier_wave_sanitized_file)
    MimeMagic.by_path(carrier_wave_sanitized_file.path)&.type == "image/jpeg"
  end
end
