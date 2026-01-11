# frozen_string_literal: true

describe UsagesController, type: :controller do
  render_views

  let(:project) { FactoryBot.create :user_project }
  let(:owner) { project.owner }
  let(:new_usage) { FactoryBot.build :usage }

  subject { response }

  describe 'GET new' do
    before do
      sign_in owner
      get :new, params: { owner_name: owner.to_param, project_id: project }, xhr: true
    end
    it { is_expected.to render_template :new }
  end

  describe 'GET edit' do
    before do
      sign_in owner
      usage = FactoryBot.create(:usage, project: project)
      get :edit, params: { owner_name: owner.to_param, project_id: project, id: usage.id }, xhr: true
    end
    it { is_expected.to render_template :edit }
  end

  describe 'POST create' do
    context 'when a user is logged in' do
      before do
        sign_in owner
        project.usages.destroy_all
        post :create, params: { owner_name: owner, project_id: project.name, usage: { title: 'title' } }, xhr: true
        project.reload
      end
      it { is_expected.to render_template :create }
      it 'has 1 usage' do
        expect(project.usages.count).to eq 1
      end
    end

    context 'when a user is not logged in' do
      before do
        project.usages.destroy_all
        post :create, params: { owner_name: owner, project_id: project.name, usage: { title: 'title' } }, xhr: true
        project.reload
      end
      it { is_expected.to_not render_template :create }
      it 'does not create a usage' do
        expect(project.usages.count).to eq 0
      end
    end

    context 'スパムキーワードを含む場合' do
      let!(:spam_keyword) { create(:spam_keyword, keyword: 'casino', enabled: true) }

      before do
        sign_in owner
        project.usages.destroy_all
        SpamKeywordDetector.clear_cache
      end
      after { SpamKeywordDetector.clear_cache }

      it 'タイトルにスパムキーワードを含む場合は拒否されること' do
        post :create, params: { owner_name: owner, project_id: project.name, usage: { title: 'Visit casino now', description: 'desc' } }, xhr: true
        expect(response).to have_http_status(:unprocessable_entity)
        expect(JSON.parse(response.body, symbolize_names: true)[:error]).to include('prohibited keyword')
      end

      it '説明にスパムキーワードを含む場合は拒否されること' do
        post :create, params: { owner_name: owner, project_id: project.name, usage: { title: 'title', description: 'Visit casino now' } }, xhr: true
        expect(response).to have_http_status(:unprocessable_entity)
      end

      it 'Usageが作成されないこと' do
        expect {
          post :create, params: { owner_name: owner, project_id: project.name, usage: { title: 'Visit casino now', description: 'desc' } }, xhr: true
        }.not_to change(Card::Usage, :count)
      end
    end
  end

  describe 'PATCH update' do
    context 'when current_user is a project owner' do
      before do
        sign_in owner
        usage = FactoryBot.create(:usage, project: project, title: 'foo', description: 'bar')
        patch :update,
          params: { owner_name: owner, project_id: project, id: usage.id, usage: { title: 'title' } },
          xhr: true
      end
      it { is_expected.to render_template :update }
    end

    context 'when current_user is a contributor' do
      before do
        contributor = FactoryBot.create(:user)
        sign_in contributor
        
        usage = FactoryBot.create(:usage, project: project, title: 'foo', description: 'bar')
        FactoryBot.create(:contribution, contributor: contributor, card: usage)
        patch :update,
          params: { owner_name: owner, project_id: project, id: usage.id, usage: { title: 'title' } },
          xhr: true
      end
      it { is_expected.to render_template :update }
    end

    context 'when current_user is not a contributor' do
      before do
        sign_in FactoryBot.create(:user)

        usage = FactoryBot.create(:usage, project: project, title: 'foo', description: 'bar')
        patch :update,
          params: { owner_name: owner, project_id: project, id: usage.id, usage: { title: 'title' } },
          xhr: true
      end
      it { is_expected.to_not render_template :update }
    end

    context 'スパムキーワードを含む場合' do
      let!(:spam_keyword) { create(:spam_keyword, keyword: 'casino', enabled: true) }
      let!(:usage) { FactoryBot.create(:usage, project: project, title: 'foo', description: 'bar') }

      before do
        sign_in owner
        SpamKeywordDetector.clear_cache
      end
      after { SpamKeywordDetector.clear_cache }

      it 'タイトルにスパムキーワードを含む場合は拒否されること' do
        patch :update,
          params: { owner_name: owner, project_id: project, id: usage.id, usage: { title: 'Visit casino now', description: 'new_desc' } },
          xhr: true
        expect(response).to have_http_status(:unprocessable_entity)
        expect(JSON.parse(response.body, symbolize_names: true)[:error]).to include('prohibited keyword')
      end

      it '説明にスパムキーワードを含む場合は拒否されること' do
        patch :update,
          params: { owner_name: owner, project_id: project, id: usage.id, usage: { title: 'new_title', description: 'Visit casino now' } },
          xhr: true
        expect(response).to have_http_status(:unprocessable_entity)
      end

      it 'Usageが更新されないこと' do
        original_title = usage.title
        patch :update,
          params: { owner_name: owner, project_id: project, id: usage.id, usage: { title: 'Visit casino now', description: 'new_desc' } },
          xhr: true
        usage.reload
        expect(usage.title).to eq(original_title)
      end
    end
  end

  describe 'DELETE destroy' do
    context 'when current_user is a project owner' do
      before do
        sign_in owner

        usage = FactoryBot.create(:usage, project: project, title: 'foo', description: 'bar')
        delete :destroy, params: { owner_name: owner.to_param, project_id: project, id: usage.id }, xhr: true
      end
      it { is_expected.to have_http_status(:ok) }
      it { expect(JSON.parse(response.body, symbolize_names: true)).to eq({ success: true }) }
    end

    context 'when current_user is a contributor' do
      before do
        contributor = FactoryBot.create(:user)
        sign_in contributor

        usage = FactoryBot.create(:usage, project: project, title: 'foo', description: 'bar')
        FactoryBot.create(:contribution, contributor: contributor, card: usage)
        delete :destroy, params: { owner_name: owner.to_param, project_id: project, id: usage.id }, xhr: true
      end
      it { is_expected.to have_http_status(:ok) }
      it { expect(JSON.parse(response.body, symbolize_names: true)).to eq({ success: true }) }
    end
    
    context 'when current_user is not a contributor' do
      before do
        sign_in FactoryBot.create(:user)

        usage = FactoryBot.create(:usage, project: project, title: 'foo', description: 'bar')
        delete :destroy, params: { owner_name: owner.to_param, project_id: project, id: usage.id }, xhr: true
      end
      it { is_expected.to have_http_status(:unauthorized) }
    end
  end
end
