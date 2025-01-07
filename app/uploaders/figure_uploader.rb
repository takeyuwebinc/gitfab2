class FigureUploader < CarrierWave::Uploader::Base
  include CarrierWave::Vips
  include StripGps

  storage :file

  def store_dir
    "uploads/#{model.class.to_s.underscore}/#{mounted_as}/#{model.id}"
  end

  version :small do
    process resize_to_fit: [400, 400]
    process :add_play_btn, if: :gif?
  end

  version :medium do
    process resize_to_fit: [820, 10_000]
  end

  def extension_white_list
    %w(jpg jpeg gif png)
  end

  def default_url
    '/images/fallback/blank.png'
  end

  def play_btn_path
    Rails.root + 'app/assets/images/play.png'
  end

  def add_play_btn
    vips! do |builder|
      builder.custom do |img| # img is a Vips::Image
        vips_loader = img.get_value("vips-loader")
        case vips_loader
        when "gifload"
          # 再生ボタンを合成
          play_btn_img = Vips::Image.new_from_file(play_btn_path.to_s)
          overlay_center(img, play_btn_img)
        else
          # not gif
          nil # return the original
        end
      end
    end
  end

  def overlay_center(src_img, overlay_img)
    src_img = src_img.colourspace("srgb")
    overlay_img = overlay_img.colourspace("srgb")
    x = ((src_img.width - overlay_img.width) / 2).floor
    y = ((src_img.height - overlay_img.height) / 2).floor
    alpha = overlay_img[3]
    overlay_img_rgb = overlay_img.extract_band(0, n: 3)
    overlay_img_with_alpha = overlay_img_rgb.bandjoin(alpha)
    src_img.composite(overlay_img_with_alpha, :over, x:, y:)
  end

  def gif?(carrier_wave_sanitized_file)
    MimeMagic.by_path(carrier_wave_sanitized_file.path).type == "image/gif"
  end
end
