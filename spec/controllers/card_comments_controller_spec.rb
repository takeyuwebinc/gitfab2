# frozen_string_literal: true

describe CardCommentsController, type: :controller do
  render_views

  let(:user1) { FactoryBot.create :user }
  let(:project) { FactoryBot.create :user_project }

  subject { response }

  describe 'POST create' do
    context 'with valid parameters' do
      before do
        note_card = FactoryBot.create(:note_card, project: project)

        sign_in user1
        post :create,
          params: {
            user_id: project.owner.to_param, project_id: project.id,
            note_card_id: note_card.id, card_comment: { body: 'foo' }
          },
          xhr: true
      end
      it 'should render create with ok(200)' do
        aggregate_failures do
          is_expected.to have_http_status(:ok)
          is_expected.to render_template :create
        end
      end
    end

    context 'with invalid parameters' do
      before do
        note_card = FactoryBot.create(:note_card, project: project)

        sign_in user1
        post :create,
          params: {
            user_id: project.owner.to_param, project_id: project.id,
            note_card_id: note_card.id, card_comment: { body: '' }
          },
          xhr: true
      end
      it do
        aggregate_failures do
          is_expected.to have_http_status(400)
          expect(JSON.parse(response.body, symbolize_names: true)).to eq({ success: false, message: { body: ["can't be blank"] } })
        end
      end
    end
  end

  describe 'DELETE destroy' do
    let(:note_card) { FactoryBot.create(:note_card, project: project) }
    let(:comment) { FactoryBot.create(:card_comment, user: user1, card: note_card) }
    before do
      sign_in project.owner
      delete :destroy,
        params: { user_id: project.owner.to_param, project_id: project.id, note_card_id: note_card.id, id: comment.id },
        xhr: true
    end
    it { expect(note_card.comments.size).to eq 0 }
    it { expect(JSON.parse(response.body, symbolize_names: true)).to eq({ success: true  }) }
  end
end