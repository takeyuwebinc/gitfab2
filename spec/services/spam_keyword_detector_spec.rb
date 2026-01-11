require 'spec_helper'

RSpec.describe SpamKeywordDetector do
  before do
    described_class.clear_cache
  end

  after do
    described_class.clear_cache
  end

  describe '.detect' do
    let(:user) { create(:user) }

    context 'スパムキーワードが含まれている場合' do
      let!(:spam_keyword) { create(:spam_keyword, keyword: 'casino', enabled: true) }

      it '検出されたSpamKeywordを返すこと' do
        result = described_class.detect(user: user, contents: 'Visit our casino now!')
        expect(result).to eq(spam_keyword)
      end

      it '複数のコンテンツからでも検出すること' do
        result = described_class.detect(user: user, contents: [ 'Hello', 'Visit casino' ])
        expect(result).to eq(spam_keyword)
      end

      it '大文字・小文字を区別しないこと' do
        result = described_class.detect(user: user, contents: 'Visit our CASINO now!')
        expect(result).to eq(spam_keyword)
      end
    end

    context 'スパムキーワードが含まれていない場合' do
      let!(:spam_keyword) { create(:spam_keyword, keyword: 'casino', enabled: true) }

      it 'nilを返すこと' do
        result = described_class.detect(user: user, contents: 'Hello World')
        expect(result).to be_nil
      end
    end

    context '無効化されたキーワードの場合' do
      let!(:spam_keyword) { create(:spam_keyword, keyword: 'casino', enabled: false) }

      it '検出しないこと' do
        result = described_class.detect(user: user, contents: 'Visit our casino now!')
        expect(result).to be_nil
      end
    end

    context 'システム管理者の場合' do
      let(:admin) { create(:user, authority: 'admin') }
      let!(:spam_keyword) { create(:spam_keyword, keyword: 'casino', enabled: true) }

      it '一般ユーザーと同様に検出を行うこと' do
        result = described_class.detect(user: admin, contents: 'Visit our casino now!')
        expect(result).to eq(spam_keyword)
      end
    end

    context 'ユーザーがnilの場合' do
      let!(:spam_keyword) { create(:spam_keyword, keyword: 'casino', enabled: true) }

      it '検出を行うこと（未認証ユーザーも対象）' do
        result = described_class.detect(user: nil, contents: 'Visit our casino now!')
        expect(result).to eq(spam_keyword)
      end
    end

    context 'コンテンツが空の場合' do
      let!(:spam_keyword) { create(:spam_keyword, keyword: 'casino', enabled: true) }

      it 'nilを返すこと' do
        result = described_class.detect(user: user, contents: [])
        expect(result).to be_nil
      end

      it 'nilのコンテンツを無視すること' do
        result = described_class.detect(user: user, contents: [ nil, '', nil ])
        expect(result).to be_nil
      end
    end

    context '複数のキーワードが登録されている場合' do
      let!(:spam_keyword1) { create(:spam_keyword, keyword: 'casino', enabled: true) }
      let!(:spam_keyword2) { create(:spam_keyword, keyword: 'viagra', enabled: true) }

      it '最初に見つかったキーワードを返すこと' do
        result = described_class.detect(user: user, contents: 'casino and viagra')
        expect(result).to be_in([ spam_keyword1, spam_keyword2 ])
      end
    end
  end

  describe '.detect_with_logging' do
    let(:user) { create(:user) }
    let!(:spam_keyword) { create(:spam_keyword, keyword: 'casino', enabled: true) }

    context 'スパムキーワードが検出された場合' do
      it 'ログを出力すること' do
        expect(Rails.logger).to receive(:info).with(/SpamKeywordDetector.*casino/)

        described_class.detect_with_logging(
          user: user,
          contents: 'Visit our casino now!',
          content_type: 'Project'
        )
      end

      it '検出されたSpamKeywordを返すこと' do
        result = described_class.detect_with_logging(
          user: user,
          contents: 'Visit our casino now!',
          content_type: 'Project'
        )
        expect(result).to eq(spam_keyword)
      end
    end

    context 'スパムキーワードが検出されなかった場合' do
      it 'ログを出力しないこと' do
        expect(Rails.logger).not_to receive(:info)

        described_class.detect_with_logging(
          user: user,
          contents: 'Hello World',
          content_type: 'Project'
        )
      end

      it 'nilを返すこと' do
        result = described_class.detect_with_logging(
          user: user,
          contents: 'Hello World',
          content_type: 'Project'
        )
        expect(result).to be_nil
      end
    end
  end

  describe '.clear_cache' do
    it 'キャッシュキーを削除すること' do
      expect(Rails.cache).to receive(:delete).with(SpamKeywordDetector::CACHE_KEY).at_least(:once)
      described_class.clear_cache
    end
  end
end
