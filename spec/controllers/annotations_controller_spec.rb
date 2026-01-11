# frozen_string_literal: true

describe AnnotationsController, type: :controller do
  render_views

  let(:project) { FactoryBot.create :user_project }
  let(:user) { project.owner }

  subject { response }

  describe 'GET #new' do
    before do
      sign_in user
      state = project.states.create type: Card::State.name, description: 'foo'
      get :new, params: { owner_name: user, project_id: project, state_id: state.id }, xhr: true
    end
    it { is_expected.to render_template :new }
  end

  describe 'GET #edit' do
    before do
      sign_in user
      state = project.states.create type: Card::State.name, description: 'foo'
      annotation = state.annotations.create description: 'ann'
      get :edit, params: {
        owner_name: user, project_id: project, state_id: state.id, id: annotation.id
      }, xhr: true
    end
    it { is_expected.to render_template :edit }
  end

  describe 'GET #show' do
    before do
      sign_in user
      state = project.states.create type: Card::State.name, description: 'foo'
      annotation = state.annotations.create description: 'ann'
      get :show,
        params: { owner_name: user, project_id: project, state_id: state.id, id: annotation.id },
        xhr: true
    end
    it { is_expected.to render_template :show }
  end

  describe 'POST #create' do
    describe 'with correct parameters' do
      subject do
        state = project.states.create type: Card::State.name, description: 'foo'
        post :create,
          params: { owner_name: user, project_id: project, state_id: state.id, annotation: { description: 'ann' } },
          xhr: true
      end

      context 'when a user is signed in' do
        before { sign_in(FactoryBot.create(:user)) }

        it { is_expected.to render_template :create }
        it { expect { subject }.to change(Card::Annotation, :count).by(1) }
      end

      context 'when a user is not signed in' do
        it { is_expected.to_not render_template :create }
        it { expect { subject }.to_not change(Card::Annotation, :count) }
      end
    end

    context 'スパムキーワードを含む場合' do
      let!(:spam_keyword) { create(:spam_keyword, keyword: 'casino', enabled: true) }
      let!(:state) { project.states.create type: Card::State.name, description: 'foo' }

      before do
        sign_in(FactoryBot.create(:user))
        SpamKeywordDetector.clear_cache
      end
      after { SpamKeywordDetector.clear_cache }

      it 'タイトルにスパムキーワードを含む場合は拒否されること' do
        post :create,
          params: { owner_name: user, project_id: project, state_id: state.id, annotation: { title: 'Visit casino now', description: 'ann' } },
          xhr: true
        expect(response).to have_http_status(:unprocessable_entity)
        expect(JSON.parse(response.body, symbolize_names: true)[:error]).to include('禁止されているキーワード')
      end

      it '説明にスパムキーワードを含む場合は拒否されること' do
        post :create,
          params: { owner_name: user, project_id: project, state_id: state.id, annotation: { title: 'foo', description: 'Visit casino now' } },
          xhr: true
        expect(response).to have_http_status(:unprocessable_entity)
      end

      it 'Annotationが作成されないこと' do
        expect {
          post :create,
            params: { owner_name: user, project_id: project, state_id: state.id, annotation: { title: 'Visit casino now', description: 'ann' } },
            xhr: true
        }.not_to change(Card::Annotation, :count)
      end
    end
  end

  describe 'PATCH #update' do
    context 'when a current user is a project owner' do
      let(:current_user) { user }
      before { sign_in(current_user) }

      describe 'with correct parameters' do
        before do
          state = project.states.create type: Card::State.name, description: 'foo'
          annotation = state.annotations.create description: 'ann'
          patch :update,
            params: {
              owner_name: user, project_id: project, state_id: state.id,
              id: annotation.id, annotation: { description: '_ann' }
            },
            xhr: true
        end
        it { is_expected.to render_template :update }
      end

      describe 'with incorrect parameters' do
        before do
          state = project.states.create type: Card::State.name, description: 'foo'
          annotation = state.annotations.create description: 'ann'
          patch :update,
            params: {
              owner_name: user, project_id: project, state_id: state.id,
              id: annotation.id, annotation: { type: nil, description: '_ann' }
            },
            xhr: true
        end
        it { expect(response.status).to eq(400) }
      end
    end

    context 'when a current user is not a project owner' do
      let(:current_user) { FactoryBot.create(:user) }
      before { sign_in(current_user) }

      describe 'with correct parameters' do
        before do
          state = project.states.create type: Card::State.name, description: 'foo'
          annotation = state.annotations.create description: 'ann'
          patch :update,
            params: {
              owner_name: user, project_id: project, state_id: state.id,
              id: annotation.id, annotation: { description: '_ann' }
            },
            xhr: true
        end
        it { is_expected.to_not render_template :update }
      end
    end

    context 'when a current user is a annotation contributor' do
      let(:current_user) { FactoryBot.create(:user) }
      before { sign_in(current_user) }

      describe 'with correct parameters' do
        before do
          state = FactoryBot.create(:state, project: project)
          annotation = FactoryBot.create(:annotation, state: state)
          FactoryBot.create(:contribution, contributor: current_user, card: annotation)
          patch :update,
            params: {
              owner_name: user, project_id: project, state_id: state.id,
              id: annotation.id, annotation: { description: '_ann' }
            },
            xhr: true
        end
        it { is_expected.to render_template :update }
      end
    end

    context 'スパムキーワードを含む場合' do
      let(:current_user) { user }
      let!(:spam_keyword) { create(:spam_keyword, keyword: 'casino', enabled: true) }
      let!(:state) { FactoryBot.create(:state, project: project) }
      let!(:annotation) { FactoryBot.create(:annotation, state: state) }

      before do
        sign_in(current_user)
        SpamKeywordDetector.clear_cache
      end
      after { SpamKeywordDetector.clear_cache }

      it 'タイトルにスパムキーワードを含む場合は拒否されること' do
        patch :update,
          params: {
            owner_name: user, project_id: project, state_id: state.id,
            id: annotation.id, annotation: { title: 'Visit casino now', description: 'new_desc' }
          },
          xhr: true
        expect(response).to have_http_status(:unprocessable_entity)
        expect(JSON.parse(response.body, symbolize_names: true)[:error]).to include('禁止されているキーワード')
      end

      it '説明にスパムキーワードを含む場合は拒否されること' do
        patch :update,
          params: {
            owner_name: user, project_id: project, state_id: state.id,
            id: annotation.id, annotation: { title: 'new_title', description: 'Visit casino now' }
          },
          xhr: true
        expect(response).to have_http_status(:unprocessable_entity)
      end

      it 'Annotationが更新されないこと' do
        original_description = annotation.description
        patch :update,
          params: {
            owner_name: user, project_id: project, state_id: state.id,
            id: annotation.id, annotation: { title: 'Visit casino now', description: 'new_desc' }
          },
          xhr: true
        annotation.reload
        expect(annotation.description).to eq(original_description)
      end
    end

    context 'when a user is not logged in' do
      describe 'with correct parameters' do
        before do
          state = project.states.create type: Card::State.name, description: 'foo'
          annotation = state.annotations.create description: 'ann'
          patch :update,
            params: {
              owner_name: user, project_id: project, state_id: state.id,
              id: annotation.id, annotation: { description: '_ann' }
            },
            xhr: true
        end
        it { is_expected.to_not render_template :update }
      end
    end
  end

  describe 'DELETE #destroy' do
    context 'when a current user is a project owner' do
      let(:current_user) { user }
      before do
        sign_in current_user
        state = project.states.create type: Card::State.name, description: 'foo'
        annotation = state.annotations.create description: 'ann'
        delete :destroy,
          params: { owner_name: user, project_id: project, state_id: state.id, id: annotation.id },
          xhr: true
      end
      it { is_expected.to have_http_status(:ok) }
      it { expect(JSON.parse(response.body, symbolize_names: true)).to eq({ success: true }) }
    end

    context 'when a current user is not a project owner' do
      let(:current_user) { FactoryBot.create(:user) }
      before do
        sign_in current_user
        state = project.states.create type: Card::State.name, description: 'foo'
        annotation = state.annotations.create description: 'ann'
        delete :destroy,
          params: { owner_name: user, project_id: project, state_id: state.id, id: annotation.id },
          xhr: true
      end
      it { is_expected.to have_http_status(:unauthorized) }
    end

    context 'when a current user is a annotation contributor' do
      let(:current_user) { FactoryBot.create(:user) }
      before do
        sign_in(current_user)
        state = FactoryBot.create(:state, project: project)
        annotation = FactoryBot.create(:annotation, state: state)
        FactoryBot.create(:contribution, contributor: current_user, card: annotation)
        delete :destroy,
          params: { owner_name: user, project_id: project, state_id: state.id, id: annotation.id },
          xhr: true
      end
      it { is_expected.to have_http_status(:ok) }
    end

    context 'when a user is not logged' do
      before do
        state = project.states.create type: Card::State.name, description: 'foo'
        annotation = state.annotations.create description: 'ann'
        delete :destroy,
          params: { owner_name: user, project_id: project, state_id: state.id, id: annotation.id },
          xhr: true
      end
      it { is_expected.to have_http_status(:unauthorized) }
    end
  end

  describe 'POST #to_state' do
    context 'when a current user is a project owner' do
      let(:current_user) { user }
      before { sign_in(current_user) }

      describe 'with correct parameters' do
        before do
          state = project.states.create type: Card::State.name, description: 'foo'
          annotation = state.annotations.create(description: 'ann')
          get :to_state,
            params: { owner_name: user.slug, project_id: project, state_id: state.id, annotation_id: annotation.id },
            xhr: true
        end
        it { expect(response).to have_http_status(:ok) }
      end

      describe 'with incorrect parameters' do
        before do
          state = project.states.create type: Card::State.name, description: 'foo'
          state.annotations.create description: 'ann'
          get :to_state,
            params: { owner_name: user.slug, project_id: project, state_id: state.id, annotation_id: 'unexisted_id' },
            xhr: true
        end
        it { expect(response).to have_http_status(:not_found) }
        it { expect(response).to render_template(layout: false) }
      end
    end
    
    context 'when a current user is not a project owner' do
      let(:current_user) { FactoryBot.create(:user) }
      before { sign_in(current_user) }

      describe 'with correct parameters' do
        before do
          state = project.states.create type: Card::State.name, description: 'foo'
          annotation = state.annotations.create(description: 'ann')
          get :to_state,
            params: { owner_name: user.slug, project_id: project, state_id: state.id, annotation_id: annotation.id },
            xhr: true
        end
        it { expect(response).to_not have_http_status(:ok) }
      end
    end
  end

  # TODO: create update_contribution spec
  describe 'update_contribution' do
    describe 'save_current_users_contribution' do
    end
    describe 'create_new_contribution' do
    end
  end

  describe 'readonly mode restriction' do
    let(:state) { FactoryBot.create(:state, project: project, annotations_count: 0) }
    let(:annotation) { FactoryBot.create(:annotation, state: state) }

    before do
      sign_in user
      allow(SystemSetting).to receive(:readonly_mode_enabled?).and_return(true)
    end

    describe 'POST create' do
      it 'does not create an annotation' do
        expect {
          post :create,
            params: { owner_name: user, project_id: project, state_id: state.id, annotation: { description: 'ann' } },
            xhr: true
        }.not_to change(Card::Annotation, :count)
      end

      it 'returns 503' do
        post :create,
          params: { owner_name: user, project_id: project, state_id: state.id, annotation: { description: 'ann' } },
          xhr: true
        expect(response).to have_http_status(:service_unavailable)
      end
    end

    describe 'PATCH update' do
      it 'does not update the annotation' do
        original_description = annotation.description
        patch :update,
          params: {
            owner_name: user, project_id: project, state_id: state.id,
            id: annotation.id, annotation: { description: 'new_ann' }
          },
          xhr: true
        expect(annotation.reload.description).to eq(original_description)
      end

      it 'returns 503' do
        patch :update,
          params: {
            owner_name: user, project_id: project, state_id: state.id,
            id: annotation.id, annotation: { description: 'new_ann' }
          },
          xhr: true
        expect(response).to have_http_status(:service_unavailable)
      end
    end

    describe 'DELETE destroy' do
      it 'does not delete the annotation' do
        annotation # create it first
        expect {
          delete :destroy,
            params: { owner_name: user, project_id: project, state_id: state.id, id: annotation.id },
            xhr: true
        }.not_to change(Card::Annotation, :count)
      end

      it 'returns 503' do
        delete :destroy,
          params: { owner_name: user, project_id: project, state_id: state.id, id: annotation.id },
          xhr: true
        expect(response).to have_http_status(:service_unavailable)
      end
    end
  end
end
