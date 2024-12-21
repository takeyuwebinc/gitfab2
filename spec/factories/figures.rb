# == Schema Information
#
# Table name: figures
#
#  id             :integer          not null, primary key
#  content        :string(255)
#  figurable_type :string(255)
#  link           :string(255)
#  created_at     :datetime
#  updated_at     :datetime
#  figurable_id   :integer
#
# Indexes
#
#  index_figures_figurable  (figurable_type,figurable_id)
#

# NOTE: frozen_string_literalをtrueにすると
# 複製の際にcan't modify frozen String

FactoryBot.define do
  factory :figure do
    figurable factory: :project
  end

  factory :link_figure, parent: :figure do
    sequence(:link) { |n| "http://test.host/link/#{n}.png" }
  end

  factory :content_figure, parent: :figure do
    content do
      Rack::Test::UploadedFile.new(
        Rails.root.join('spec', 'fixtures', 'files', 'images', 'figure.png'),
        'image/png'
      )
    end
  end
end
