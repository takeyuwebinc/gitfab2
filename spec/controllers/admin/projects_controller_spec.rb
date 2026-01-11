require 'spec_helper'

RSpec.describe Admin::ProjectsController, type: :controller do
  let(:user) { create(:user, authority: authority) }

  before { sign_in user }

  describe 'GET #index' do
    subject { get :index }

    let!(:project) { create(:project) }

    context 'with authority' do
      let(:authority) { 'admin' }

      it { is_expected.to be_successful }
    end

    context 'without authority' do
      let(:authority) { nil }
      it { is_expected.to redirect_to root_path }
    end
  end

  describe 'DELETE #destroy' do
    subject { delete :destroy, params: { id: project.id } }

    let!(:project) { create(:project) }

    context 'with authority' do
      let(:authority) { 'admin' }

      context 'when spam designation succeeds' do
        let(:result) { SpamDesignationService::Result.new(success: 1, failed: [], errors: {}) }

        before do
          allow(SpamDesignationService).to receive(:call).and_return(result)
        end

        it 'calls SpamDesignationService with the project' do
          subject
          expect(SpamDesignationService).to have_received(:call) do |projects|
            expect(projects.map(&:id)).to eq [project.id]
          end
        end

        it 'redirects to index with success notice' do
          subject
          expect(response).to redirect_to(admin_projects_path)
          expect(flash[:notice]).to eq 'プロジェクトをスパム認定しました'
        end
      end

      context 'when spam designation fails' do
        let(:result) { SpamDesignationService::Result.new(success: 0, failed: [project], errors: { project.id => '処理に失敗しました' }) }

        before do
          allow(SpamDesignationService).to receive(:call).and_return(result)
        end

        it 'redirects to index with alert' do
          subject
          expect(response).to redirect_to(admin_projects_path)
          expect(flash[:alert]).to eq 'スパム認定に失敗しました'
        end
      end
    end

    context 'without authority' do
      let(:authority) { nil }

      it 'does not call SpamDesignationService' do
        expect(SpamDesignationService).not_to receive(:call)
        subject
      end

      it { is_expected.to redirect_to root_path }
    end
  end

  describe 'POST #batch_spam' do
    subject { post :batch_spam, params: params }

    context 'with authority' do
      let(:authority) { 'admin' }

      context 'with selected projects' do
        let!(:project1) { create(:project) }
        let!(:project2) { create(:project) }
        let(:params) { { project_ids: [project1.id.to_s, project2.id.to_s] } }
        let(:result) { SpamDesignationService::Result.new(success: 2, failed: [], errors: {}) }

        before do
          allow(SpamDesignationService).to receive(:call).and_return(result)
        end

        it 'calls SpamDesignationService with selected projects' do
          subject
          expect(SpamDesignationService).to have_received(:call) do |projects|
            expect(projects.pluck(:id)).to match_array([project1.id, project2.id])
          end
        end

        it 'redirects to index with success notice' do
          subject
          expect(response).to redirect_to(admin_projects_path)
          expect(flash[:notice]).to eq '2件のプロジェクトをスパム認定しました'
        end
      end

      context 'when some projects fail' do
        let!(:project1) { create(:project) }
        let!(:project2) { create(:project) }
        let(:params) { { project_ids: [project1.id.to_s, project2.id.to_s] } }
        let(:result) { SpamDesignationService::Result.new(success: 1, failed: [project2], errors: { project2.id => '処理に失敗しました' }) }

        before do
          allow(SpamDesignationService).to receive(:call).and_return(result)
        end

        it 'redirects to index with alert' do
          subject
          expect(response).to redirect_to(admin_projects_path)
          expect(flash[:alert]).to eq '1件を処理しましたが、1件は失敗しました'
        end
      end

      context 'with no selected projects' do
        let(:params) { { project_ids: [] } }

        it 'does not call SpamDesignationService' do
          expect(SpamDesignationService).not_to receive(:call)
          subject
        end

        it 'redirects with alert' do
          subject
          expect(response).to redirect_to(admin_projects_path)
          expect(flash[:alert]).to eq 'プロジェクトを選択してください'
        end
      end

      context 'with nil project_ids' do
        let(:params) { {} }

        it 'does not call SpamDesignationService' do
          expect(SpamDesignationService).not_to receive(:call)
          subject
        end

        it 'redirects with alert' do
          subject
          expect(response).to redirect_to(admin_projects_path)
          expect(flash[:alert]).to eq 'プロジェクトを選択してください'
        end
      end
    end

    context 'without authority' do
      let(:authority) { nil }
      let(:params) { { project_ids: [create(:project).id.to_s] } }

      it 'does not call SpamDesignationService' do
        expect(SpamDesignationService).not_to receive(:call)
        subject
      end

      it { is_expected.to redirect_to root_path }
    end
  end
end
