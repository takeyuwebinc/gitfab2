describe ProjectCommentsController, type: :controller do
  describe 'POST #create' do
    subject { post :create, params: params }

    let(:project) { FactoryBot.create(:project) }
    let(:user) { FactoryBot.create(:user) }

    before { sign_in user }

    context 'with valid parameters' do
      let(:params) do
        {
          owner_name: project.owner.slug,
          project_id: project.id,
          project_comment: { body: 'valid' }
        }
      end

      it { is_expected.to redirect_to project_path(project.owner.slug, project, anchor: "project-comment-#{ProjectComment.last.id}") }

      it { expect{ subject }.to change(ProjectComment, :count).by(1) }

      specify 'commented by a signed in user' do
        subject
        expect(ProjectComment.last.user).to eq user
      end
  
      describe 'スパム投稿' do
        context 'スパム投稿者でない場合' do
          it '未確認コメントとして登録すること' do
            expect{ subject }.to change(ProjectComment, :count).by(1).and change(Notification, :count).by(1)
            expect(ProjectComment.last).to be_unconfirmed
          end
        end
        context 'スパム投稿者の場合' do
          before { user.spam_detect! }
          it 'スパムコメントとして登録すること' do
            expect{ subject }.to change(ProjectComment, :count).by(1).and change(Notification, :count).by(0)
            expect(ProjectComment.last).to be_spam
          end
        end
      end
    end

    context 'with invalid params' do
      let(:params) do
        {
          owner_name: project.owner.slug,
          project_id: project.id,
          project_comment: { body: nil }
        }
      end

      it { is_expected.to redirect_to project_path(project.owner.slug, project, anchor: "project-comment-form") }

      it { expect{ subject }.to change(ProjectComment, :count).by(0) }

      it do
        subject
        expect(flash[:alert]).to include "Body can't be blank"
      end
    end

    context 'When body length is over than 300 chars' do
      let(:params) do
        {
          owner_name: project.owner.slug,
          project_id: project.id,
          project_comment: { body: 'a'*301 }
        }
      end

      it { is_expected.to redirect_to project_path(project.owner.slug, project, anchor: "project-comment-form") }

      it { expect{ subject }.to change(ProjectComment, :count).by(0) }

      it do
        subject
        expect(flash[:alert]).to include 'Body is too long (maximum is 300 characters)'
      end
    end

    context 'スパムキーワードを含む場合' do
      let!(:spam_keyword) { FactoryBot.create(:spam_keyword, keyword: 'casino', enabled: true) }
      let(:params) do
        {
          owner_name: project.owner.slug,
          project_id: project.id,
          project_comment: { body: 'Visit casino now' }
        }
      end

      before { SpamKeywordDetector.clear_cache }
      after { SpamKeywordDetector.clear_cache }

      it 'リダイレクトされること' do
        is_expected.to redirect_to project_path(project.owner.slug, project, anchor: "project-comment-form")
      end

      it 'コメントが作成されないこと' do
        expect { subject }.not_to change(ProjectComment, :count)
      end

      it 'エラーメッセージが表示されること' do
        subject
        expect(flash[:alert]).to include('prohibited keyword')
      end

      it '入力内容が保持されること' do
        subject
        expect(flash[:project_comment_body]).to eq('Visit casino now')
      end
    end
  end

  describe 'DELETE #destroy' do
    subject { delete :destroy, params: params }

    let(:params) do
      {
        owner_name: project.owner.slug,
        project_id: project.id,
        id: project_comment.id
      }
    end

    let!(:project) { FactoryBot.create(:project) }
    let!(:project_comment) { FactoryBot.create(:project_comment, user: FactoryBot.create(:user), project: project, body: 'valid') }

    before { sign_in project.owner }

    it { is_expected.to redirect_to project_path(project.owner.slug, project, anchor: "project-comments") }

    it { expect{ subject }.to change(ProjectComment, :count).by(-1) }

    context 'when user could not delete a comment' do
      before { allow_any_instance_of(ProjectComment).to receive(:destroy).and_return(false) }

      it { is_expected.to redirect_to project_path(project.owner.slug, project, anchor: "project-comments") }

      it { expect{ subject }.to change(ProjectComment, :count).by(0) }

      it do
        subject
        expect(flash[:alert]).to eq 'Comment could not be deleted'
      end
    end

    context 'when current user can not manage the project' do
      let(:not_manager) { FactoryBot.create(:user) }

      before { sign_in not_manager }

      it { is_expected.to redirect_to project_path(project.owner.slug, project, anchor: "project-comments") }

      it { expect{ subject }.to change(ProjectComment, :count).by(0) }

      it do
        subject
        expect(flash[:alert]).to eq 'You can not delete a comment'
      end
    end
  end

  describe 'Notification' do
    subject { Notification.last }

    let(:project) { FactoryBot.create(:project) }
    let(:user) { FactoryBot.create(:user) }

    before do
      sign_in user
      post :create, params: { owner_name: project.owner.slug,
                              project_id: project.id,
                              project_comment: { body: 'valid' } }
    end

    it do
      is_expected.to have_attributes(
        notifier_id: user.id,
        notified_id: project.owner.id,
        notificatable_url: project_path(project, owner_name: project.owner.slug),
        notificatable_type: 'Project',
        body: "#{user.name} commented on #{project.title}."
      )
    end
  end

  describe 'readonly mode restriction' do
    let(:project) { FactoryBot.create(:project) }
    let(:user) { FactoryBot.create(:user) }
    let!(:project_comment) { FactoryBot.create(:project_comment, user: user, project: project, body: 'valid') }

    before do
      sign_in user
      allow(SystemSetting).to receive(:readonly_mode_enabled?).and_return(true)
    end

    describe 'POST create' do
      let(:params) do
        {
          owner_name: project.owner.slug,
          project_id: project.id,
          project_comment: { body: 'new comment' }
        }
      end

      it 'does not create a comment' do
        expect { post :create, params: params }.not_to change(ProjectComment, :count)
      end

      it 'redirects back with alert' do
        post :create, params: params
        expect(response).to redirect_to(root_path)
        expect(flash[:alert]).to eq(ReadonlyModeRestriction::READONLY_MODE_ERROR_MESSAGE)
      end
    end

    describe 'DELETE destroy' do
      let(:params) do
        {
          owner_name: project.owner.slug,
          project_id: project.id,
          id: project_comment.id
        }
      end

      before { sign_in project.owner }

      it 'does not delete the comment' do
        expect { delete :destroy, params: params }.not_to change(ProjectComment, :count)
      end

      it 'redirects back with alert' do
        delete :destroy, params: params
        expect(response).to redirect_to(root_path)
        expect(flash[:alert]).to eq(ReadonlyModeRestriction::READONLY_MODE_ERROR_MESSAGE)
      end
    end
  end
end
