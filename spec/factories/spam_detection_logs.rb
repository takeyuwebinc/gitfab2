FactoryBot.define do
  factory :spam_detection_log do
    user
    ip_address { "192.168.1.1" }
    detection_method { "keyword" }
    detection_reason { "spam" }
    content_type { "Project" }

    trait :keyword do
      detection_method { "keyword" }
      detection_reason { "viagra" }
    end

    trait :spammer do
      detection_method { "spammer" }
      detection_reason { nil }
    end

    trait :recaptcha do
      detection_method { "recaptcha" }
      detection_reason { "score=0.3, threshold=0.5" }
    end
  end
end
