# frozen_string_literal: true

# CurrentAttributes はテスト間で自動リセットされない（rspec-rails は
# ActiveSupport::TestCase を介さないため）。監査ログの操作者（Current.admin）が
# 後続テストへ漏れて偽陽性・フレーキーを生むのを防ぐため、各テストの前後でリセットする。
RSpec.configure do |config|
  config.before(:each) { ActiveSupport::CurrentAttributes.reset_all }
  config.after(:each) { ActiveSupport::CurrentAttributes.reset_all }
end
