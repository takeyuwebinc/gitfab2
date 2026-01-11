# frozen_string_literal: true

describe CardCommentsController, type: :controller do
  describe 'POST #create' do
    subject { post :create, params: { card_id: card.id, body: body }, xhr: true }

    let(:card) { FactoryBot.create(:note_card) }
    let(:user) { FactoryBot.create(:user) }
    before { sign_in(user) }

    context 'with valid parameters' do
      let(:body) { 'valid' }

      it 'renders create with ok(200)' do
        is_expected.to have_http_status(:ok)
                  .and render_template :create
      end
      it { expect{ subject }.to change{ CardComment.count }.by(1) }
  
      describe 'スパム投稿' do
        context 'スパム投稿者でない場合' do
          it '未確認コメントとして登録すること' do
            expect{ subject }.to change(CardComment, :count).by(1).and change(Notification, :count).by(1)
            expect(CardComment.last).to be_unconfirmed
          end
        end
        context 'スパム投稿者の場合' do
          before { user.spam_detect! }
          it 'スパムコメントとして登録すること' do
            expect{ subject }.to change(CardComment, :count).by(1).and change(Notification, :count).by(0)
            expect(CardComment.last).to be_spam
          end
        end
      end
    end

    context 'with invalid parameters' do
      let(:body) { '' }

      it do
        is_expected.to have_http_status(400)
        response_body = JSON.parse(response.body, symbolize_names: true)
        expect(response_body).to eq({ success: false, message: { body: ["can't be blank"] } })
      end
      it { expect{ subject }.not_to change{ CardComment.count } }
    end

    context 'スパムキーワードを含む場合' do
      let!(:spam_keyword) { FactoryBot.create(:spam_keyword, keyword: 'casino', enabled: true) }
      let(:body) { 'Visit casino now' }

      before { SpamKeywordDetector.clear_cache }
      after { SpamKeywordDetector.clear_cache }

      it 'エラーが返されること' do
        is_expected.to have_http_status(:unprocessable_entity)
        response_body = JSON.parse(response.body)
        expect(response_body["message"][""]).to include('prohibited keyword')
      end

      it 'コメントが作成されないこと' do
        expect { subject }.not_to change(CardComment, :count)
      end
    end
  end

  describe 'DELETE #destroy' do
    subject { delete :destroy, params: { id: comment.id }, xhr: true }

    let!(:comment) { FactoryBot.create(:card_comment, user: user) }
    let(:user) { FactoryBot.create(:user) }

    before { sign_in(current_user) }

    context 'user can delete a comment' do
      let(:current_user) { user }

      it do
        is_expected.to have_http_status(:ok)
        response_body = JSON.parse(response.body, symbolize_names: true)
        expect(response_body).to eq({ success: true })
      end
      it { expect{ subject }.to change{ CardComment.count }.by(-1) }
    end

    context 'user cannot delete a comment' do
      let(:current_user) { FactoryBot.create(:user) }

      it do
        is_expected.to have_http_status(400)
        response_body = JSON.parse(response.body, symbolize_names: true)
        expect(response_body).to eq({ success: false })
      end
      it { expect{ subject }.not_to change{ CardComment.count } }
    end
  end
end
