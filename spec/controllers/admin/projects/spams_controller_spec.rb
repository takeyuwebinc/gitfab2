require 'spec_helper'

RSpec.describe Admin::Projects::SpamsController, type: :controller do
  let(:user) { create(:user, authority: authority) }

  before { sign_in user }

  describe 'DELETE #destroy' do
    subject { delete :destroy, params: { project_id: project.id } }

    let!(:project) { create(:project) }

    context 'with authority' do
      let(:authority) { 'admin' }

      context 'when revocation succeeds' do
        before { allow(SpamDesignationRevocationService).to receive(:call).and_return(true) }

        it 'calls SpamDesignationRevocationService with the project' do
          subject
          expect(SpamDesignationRevocationService).to have_received(:call) do |arg|
            expect(arg).to eq project
          end
        end

        it 'redirects to the spam list with a notice' do
          subject
          expect(response).to redirect_to(admin_projects_path(status: 'spam'))
          expect(flash[:notice]).to be_present
        end
      end

      context 'when revocation fails' do
        before { allow(SpamDesignationRevocationService).to receive(:call).and_return(false) }

        it 'redirects to the spam list with an alert' do
          subject
          expect(response).to redirect_to(admin_projects_path(status: 'spam'))
          expect(flash[:alert]).to be_present
        end
      end
    end

    context 'without authority' do
      let(:authority) { nil }

      it { is_expected.to redirect_to root_path }

      it 'does not call SpamDesignationRevocationService' do
        expect(SpamDesignationRevocationService).not_to receive(:call)
        subject
      end
    end
  end
end
