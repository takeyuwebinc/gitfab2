require 'spec_helper'

RSpec.describe SpamKeyword do
  describe 'バリデーション' do
    it 'キーワードが必須であること' do
      spam_keyword = SpamKeyword.new(keyword: nil)
      expect(spam_keyword).not_to be_valid
      expect(spam_keyword.errors[:keyword]).to include("can't be blank")
    end

    it 'キーワードが一意であること' do
      create(:spam_keyword, keyword: 'spam')
      duplicate = SpamKeyword.new(keyword: 'spam')
      expect(duplicate).not_to be_valid
      expect(duplicate.errors[:keyword]).to include('has already been taken')
    end

    it 'キーワードが255文字以内であること' do
      spam_keyword = SpamKeyword.new(keyword: 'a' * 256)
      expect(spam_keyword).not_to be_valid
      expect(spam_keyword.errors[:keyword]).to include('is too long (maximum is 255 characters)')
    end

    it '255文字のキーワードは有効であること' do
      spam_keyword = SpamKeyword.new(keyword: 'a' * 255)
      expect(spam_keyword).to be_valid
    end

    it 'enabledがtrueまたはfalseであること' do
      spam_keyword = SpamKeyword.new(keyword: 'spam', enabled: nil)
      expect(spam_keyword).not_to be_valid
    end
  end

  describe 'スコープ' do
    describe '.enabled' do
      let!(:enabled_keyword) { create(:spam_keyword, keyword: 'enabled', enabled: true) }
      let!(:disabled_keyword) { create(:spam_keyword, keyword: 'disabled', enabled: false) }

      it '有効なキーワードのみを返すこと' do
        expect(SpamKeyword.enabled).to include(enabled_keyword)
        expect(SpamKeyword.enabled).not_to include(disabled_keyword)
      end
    end
  end

  describe 'コールバック' do
    describe 'strip_keyword' do
      it '前後の空白をトリムすること' do
        spam_keyword = create(:spam_keyword, keyword: '  spam  ')
        expect(spam_keyword.keyword).to eq('spam')
      end
    end
  end

  describe '#masked_keyword' do
    context '4文字以上のキーワードの場合' do
      it '先頭と末尾の文字を残し、中間を*で置換すること' do
        spam_keyword = SpamKeyword.new(keyword: 'casino')
        expect(spam_keyword.masked_keyword).to eq('c****o')
      end

      it '日本語キーワードでも正しく伏字にすること' do
        spam_keyword = SpamKeyword.new(keyword: '無料プレゼント')
        expect(spam_keyword.masked_keyword).to eq('無*****ト')
      end

      it '4文字のキーワードでも伏字にすること' do
        spam_keyword = SpamKeyword.new(keyword: 'test')
        expect(spam_keyword.masked_keyword).to eq('t**t')
      end
    end

    context '3文字以下のキーワードの場合' do
      it 'nilを返すこと' do
        spam_keyword = SpamKeyword.new(keyword: 'abc')
        expect(spam_keyword.masked_keyword).to be_nil
      end

      it '2文字でもnilを返すこと' do
        spam_keyword = SpamKeyword.new(keyword: 'ab')
        expect(spam_keyword.masked_keyword).to be_nil
      end

      it '1文字でもnilを返すこと' do
        spam_keyword = SpamKeyword.new(keyword: 'a')
        expect(spam_keyword.masked_keyword).to be_nil
      end
    end
  end

  describe '#rejection_message' do
    context '4文字以上のキーワードの場合' do
      it '伏字付きのメッセージを返すこと' do
        spam_keyword = SpamKeyword.new(keyword: 'casino')
        expect(spam_keyword.rejection_message).to include('c****o')
        expect(spam_keyword.rejection_message).to include('禁止されているキーワード')
      end
    end

    context '3文字以下のキーワードの場合' do
      it '伏字なしのメッセージを返すこと' do
        spam_keyword = SpamKeyword.new(keyword: 'abc')
        expect(spam_keyword.rejection_message).not_to include('abc')
        expect(spam_keyword.rejection_message).to include('禁止されているキーワードが含まれているため')
      end
    end
  end
end
