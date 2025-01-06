class AttachmentUploader < CarrierWave::Uploader::Base
  include CarrierWave::Vips

  version :small, if: :is_image?
  version :tmp, if: :is_stl?

  storage :file
  def store_dir
    "uploads/#{model.class.to_s.underscore}/#{mounted_as}/#{model.id}"
  end

  version :small do
    process resize_to_fit: [400, 400]
  end

  version :tmp do
    after :store, :generate_png
    def full_filename(for_file)
      'tmp_' + for_file.slice(0..-4) << 'png'
    end
  end

  # TODO: make thumbnail delayed
  # version :thumb do
  #   after :store, :generate_gif
  #   def full_filename(for_file)
  #     'thumb_' + for_file.slice(0..-4) << 'gif'
  #   end
  # end

  private

    def is_image?(file)
      file.content_type.match?(/image\//)
    end

    def is_stl?(file)
      file.filename[-4..-1] == '.stl'
    end

    def generate_png(_file)
      stl = Stl2gif::Stl.new self.file.path
      tmp_png_file = stl.to_png self.file.original_filename
      filepath = self.file.file.slice(0..-4) << 'png'
      FileUtils.mv tmp_png_file.path, filepath
    end

    def generate_gif(_file)
      stl = Stl2gif::Stl.new self.file.path
      stl.generate_frames
      tmp_gif_file = stl.to_gif self.file.original_filename
      filepath = self.file.file.slice(0..-4) << 'gif'
      FileUtils.mv tmp_gif_file.path, filepath
    end
end
