# frozen_string_literal: true

describe ProjectsController, type: :controller do
  render_views

  subject { response }

  let(:user_project) { FactoryBot.create(:user_project, is_private: is_private) }
  let(:group_project) { FactoryBot.create(:group_project, is_private: is_private) }
  let(:is_private) { false }

  describe 'GET index' do
    context 'without queries' do
      subject { get :index }

      before { FactoryBot.create(:project, :public) }

      it { is_expected.to render_template :index }
    end
  end

  %w[user group].each do |owner_type|
    let(:project) { send "#{owner_type}_project" }
    context "with a project owned by a #{owner_type}" do
      describe 'GET show' do
        subject { get :show, params: { owner_name: project.owner.slug, id: project.name } }
        it { is_expected.to render_template :show }

        context "when project is private" do
          let(:is_private) { true }

          context "when user can read project" do
            before { allow_any_instance_of(User).to receive(:is_owner_of?).with(project).and_return(true) }
            it { is_expected.to render_template(:show) }
          end

          context "when user cannot read project" do
            before { allow_any_instance_of(User).to receive(:is_owner_of?).with(project).and_return(false) }
            it { is_expected.to have_http_status(:not_found) }
          end
        end

        describe 'project comment visibility' do
          context 'when the comment is spam' do
            let!(:project_comment) { create(:project_comment, :spam, project:) }

            it 'does not show the comment' do
              subject
              expect(assigns(:project_comments)).to_not include(project_comment)
            end
          end
          context 'when the comment is not spam' do
            let!(:project_comment) { create(:project_comment, project:) }

            it 'shows the comment' do
              subject
              expect(assigns(:project_comments)).to include(project_comment)
            end
          end
        end

        describe 'state comment visibility' do
          let(:card) { create(:state, project:) }
          context 'when the comment is spam' do
            let!(:card_comment) { create(:card_comment, :spam, card:) }

            it 'does not show the comment' do
              subject
              expect(assigns(:states).map(&:visible_comments).flatten).to_not include(card_comment)
            end
          end
          context 'when the comment is not spam' do
            let!(:card_comment) { create(:card_comment, card:) }

            it 'shows the comment' do
              subject
              expect(assigns(:states).map(&:visible_comments).flatten).to include(card_comment)
            end
          end
        end

        describe 'annotation comment visibility' do
          let(:state) { create(:state, project:) }
          let(:card) { create(:annotation, state:) }
          context 'when the comment is spam' do
            let!(:card_comment) { create(:card_comment, :spam, card:) }

            it 'does not show the comment' do
              subject
              expect(assigns(:states).map(&:annotations).flatten.map(&:visible_comments).flatten).to_not include(card_comment)
            end
          end
          context 'when the comment is not spam' do
            let!(:card_comment) { create(:card_comment, card:) }

            it 'shows the comment' do
              subject
              expect(assigns(:states).map(&:annotations).flatten.map(&:visible_comments).flatten).to include(card_comment)
            end
          end
        end
      end
      describe 'GET new' do
        before do
          user_project.owner.memberships.create(group_id: group_project.owner.id, role: 'admin')
          sign_in user_project.owner
          get :new
        end
        it { is_expected.to render_template :new }
      end
      describe 'DELETE destroy' do
        context 'without collaborators' do
          before do
            user_project.owner.memberships.create(group_id: group_project.owner.id, role: 'admin')
            sign_in user_project.owner
            delete :destroy, params: { owner_name: project.owner.slug, id: project.id }
          end
          it { is_expected.to redirect_to owner_path(owner_name: project.owner.slug) }
        end
        context 'with collaborators' do
          let(:user) { FactoryBot.create :user }
          let(:group) { FactoryBot.create :group }
          before do
            user_project.owner.memberships.create(group_id: group_project.owner.id, role: 'admin')
            sign_in user_project.owner
            user.collaborations.create project_id: project
            group.collaborations.create project_id: project
            delete :destroy, params: { owner_name: project.owner.slug, id: project.id }
            user.reload
            group.reload
          end
          it { is_expected.to redirect_to owner_path(owner_name: project.owner.slug) }
          it 'has 0 collaborations' do
            aggregate_failures do
              expect(user.collaborations.size).to eq 0
              expect(group.collaborations.size).to eq 0
            end
          end
        end
      end
      describe 'GET edit' do
        before do
          user_project.owner.memberships.create(group_id: group_project.owner.id, role: 'admin')
          sign_in user_project.owner
          get :edit, params: { owner_name: project.owner.slug, id: project.id }
        end
        it { is_expected.to render_template :edit }
      end
      describe 'POST create' do
        context 'when newly creating' do
          let(:user) { FactoryBot.create :user }
          let(:new_project) { FactoryBot.build(:user_project, original: nil) }
          before do
            sign_in user
            post :create, params: { project: new_project.attributes.merge(owner_id: user.slug) }
          end
          it { is_expected.to redirect_to(edit_project_path(id: assigns(:project), owner_name: user)) }
        end
        context 'when newly creating with wrong parameters' do
          let(:user) { FactoryBot.create :user }
          let(:new_project) { FactoryBot.build(:user_project, original: nil) }
          before do
            sign_in user
            wrong_parameters = new_project.attributes
            wrong_parameters['title'] = ''
            post :create, params: { project: wrong_parameters.merge(owner_id: user.slug) }
          end
          it { is_expected.to render_template :new }
        end
        context 'without owner_id' do
          subject { post :create, params: { project: new_project.attributes } }
          let(:user) { FactoryBot.create :user }
          let(:new_project) { FactoryBot.build(:user_project, original: nil, owner: nil) }
          before { sign_in user }
          it { is_expected.to redirect_to(edit_project_path(id: assigns(:project), owner_name: user)) }
          it { expect { subject }.to change(Project, :count).by(1) }
        end
      end

      describe 'GET recipe_cards_list' do
        before do
          user_project.owner.memberships.create(group_id: group_project.owner, role: 'admin')
          sign_in user_project.owner
          get :recipe_cards_list, params: { owner_name: project.owner, project_id: project }, xhr: true
        end
        it { is_expected.to render_template 'recipe_cards_list' }
      end

      describe 'PATCH update' do
        subject { patch :update, params: params }

        let(:params) { { owner_name: project.owner, id: project.id, project: project_params } }

        before do
          user_project.owner.memberships.create(group_id: group_project.owner.id, role: 'admin')
          sign_in user_project.owner
        end

        context 'success' do
          let(:project_params) { { description: '_proj' } }
          it { is_expected.to redirect_to project_path(owner_name: project.owner, id: project) }
        end

        context 'raising error by invalid title' do
          let(:project_params) { { title: '' } }
          it { is_expected.to render_template :edit }
        end
      end
    end
  end

  describe 'DELETE destroy_or_render_edit' do
    subject { delete :destroy_or_render_edit, params: { owner_name: project.owner.slug, project_id: project.id } }
    let(:user) { FactoryBot.create(:user) }
    before { sign_in user }

    context 'when destroy user project' do
      let(:project) { FactoryBot.create(:user_project, owner: user) }
      it { is_expected.to redirect_to owner_path(owner_name: project.owner.slug) }
    end

    context 'when destroy group project' do
      let(:project) { FactoryBot.create(:group_project) }
      before { user.memberships.create(group_id: project.owner.id, role: 'admin') }
      it { is_expected.to redirect_to owner_path(owner_name: project.owner.slug) }
    end
  end

  describe 'raise on soft_destroy!' do
    let(:project) { FactoryBot.create(:user_project) }
    before do
      allow_any_instance_of(Project).to receive(:soft_destroy!).and_raise(error)
      sign_in project.owner
    end

    context 'in destroy' do
      subject { delete :destroy, params: { owner_name: project.owner.slug, id: project } }

      context 'ActiveRecord::RecordNotDestroyed' do
        let(:error) { ActiveRecord::RecordNotDestroyed }
        it { is_expected.to redirect_to owner_path(owner_name: project.owner.slug) }
        it do
          subject
          expect(flash.now[:alert]).to eq 'Project could not be deleted.'
        end
      end

      context 'ActiveRecord::RecordNotSaved' do
        let(:error) { ActiveRecord::RecordNotSaved }
        it { is_expected.to redirect_to owner_path(owner_name: project.owner.slug) }
        it do
          subject
          expect(flash.now[:alert]).to eq 'Project could not be deleted.'
        end
      end
    end

    context 'in destroy_or_render_edit' do
      subject { delete :destroy_or_render_edit, params: { owner_name: project.owner.slug, project_id: project.id } }

      context 'ActiveRecord::RecordNotDestroyed' do
        let(:error) { ActiveRecord::RecordNotDestroyed }
        it { is_expected.to render_template :edit }
        it do
          subject
          expect(flash.now[:alert]).to eq 'Project could not be deleted.'
        end
      end

      context 'ActiveRecord::RecordNotSaved' do
        let(:error) { ActiveRecord::RecordNotSaved }
        it { is_expected.to render_template :edit }
        it do
          subject
          expect(flash.now[:alert]).to eq 'Project could not be deleted.'
        end
      end
    end
  end

  describe 'POST #fork' do
    subject { post :fork, params: { owner_name: project.owner, project_id: project, owner_id: target_owner.slug } }

    before { sign_in(current_user) }

    describe 'check the target_owner' do
      let!(:project) { FactoryBot.create(:project, :public) }

      context 'target_owner is a User' do
        let(:target_owner) { FactoryBot.create(:user) }
  
        context 'when the user is himself' do
          let(:current_user) { target_owner }
  
          it { is_expected.to redirect_to project_path(target_owner, Project.last) }
          it { expect{ subject }.to change{ Project.count }.by(1) }
        end
  
        context 'when the user is not himself' do
          let(:current_user) { FactoryBot.create(:user) }
  
          it { expect{ subject }.to_not change{ Project.count } }
        end
      end
  
      context 'target_owner is a Group' do
        let(:current_user) { FactoryBot.create(:user) }
        let(:target_owner) { FactoryBot.create(:group) }
  
        context 'when the user is in' do
          context 'when the role is an administrator' do
            before { FactoryBot.create(:membership, role: "admin", group: target_owner, user: current_user) }
    
            it { is_expected.to redirect_to project_path(target_owner, Project.last) }
            it { expect{ subject }.to change{ Project.count }.by(1) }
          end
  
          context 'when the role is a editor' do
            before { FactoryBot.create(:membership, role: "editor", group: target_owner, user: current_user) }
  
            it { expect{ subject }.to_not change{ Project.count } }
          end
        end
  
        context 'when the user is not in' do
          it { expect{ subject }.to_not change{ Project.count } }
        end
      end
    end

    describe 'check the project visibility' do
      let!(:project) { FactoryBot.create(:project, :private) }
      let(:target_owner) { FactoryBot.create(:user) }
      let(:current_user) { target_owner }
  
      it { expect{ subject }.to_not change{ Project.count } }
    end
  end

  describe 'PATCH #update' do
    subject do
      patch :change_order,
        params: {
          owner_name: project.owner,
          project_id: project,
          project: {
            states_attributes: [
              { id: card1.id, position: 3 },
              { id: card2.id, position: 2 },
              { id: card3.id, position: 1 }
            ]
          }
        },
        xhr: true
    end

    let!(:project) { FactoryBot.create(:project, updated_at: 1.day.ago) }
    let(:card1) { project.states.create!(description: 'foo', position: 1) }
    let(:card2) { project.states.create!(description: 'foo', position: 2) }
    let(:card3) { project.states.create!(description: 'foo', position: 3) }

    before { sign_in(project.owner) }

    it do
      subject
      expect(JSON.parse(response.body, symbolize_names: true)).to eq({ success: true })
    end

    it 'updates card positions' do
      subject
      aggregate_failures do
        expect(card1.reload.position).to eq 3
        expect(card2.reload.position).to eq 2
        expect(card3.reload.position).to eq 1
      end
    end

    it "updates project's updated_at" do
      expect{ subject }.to change{ project.reload.updated_at }
    end
  end

  describe 'GET search' do
    context 'with no queries' do
      subject { get :search }

      before { FactoryBot.create_list(:project, 13, :public) }

      it 'gets 12 projects for the 1st page' do
        subject
        expect(assigns(:projects).count).to eq 12
      end

      it { is_expected.to render_template :search }
    end

    shared_examples_for '検索結果' do |query|
      it do
        get :search, params: { q: query }

        expect(response).to render_template :search
        expect(assigns(:projects)).to include(public_user_project, public_group_project)

        aggregate_failures do
          expect(assigns(:projects)).not_to include(private_user_project)
          expect(assigns(:projects)).not_to include(deleted_user_project)
          expect(assigns(:projects)).not_to include(one_of_the_project)
        end
      end
    end

    shared_examples_for '検索結果(public user project only)' do |query|
      it do
        get :search, params: { q: query }

        expect(response).to render_template :search
        expect(assigns(:projects)).to include(public_user_project)

        aggregate_failures do
          expect(assigns(:projects)).not_to include(public_group_project)
          expect(assigns(:projects)).not_to include(private_user_project)
          expect(assigns(:projects)).not_to include(deleted_user_project)
          expect(assigns(:projects)).not_to include(one_of_the_project)
        end
      end
    end

    shared_examples_for '検索結果(public group project only)' do |query|
      it do
        get :search, params: { q: query }

        expect(response).to render_template :search
        expect(assigns(:projects)).to include(public_group_project)

        aggregate_failures do
          expect(assigns(:projects)).not_to include(public_user_project)
          expect(assigns(:projects)).not_to include(private_user_project)
          expect(assigns(:projects)).not_to include(deleted_user_project)
          expect(assigns(:projects)).not_to include(one_of_the_project)
        end
      end
    end

    describe 'Search projects by name' do
      shared_context 'projects with name' do |matched, unmatched|
        # 公開プロジェクト
        # デフォルトで公開になっているが明示的に
        let!(:public_user_project) { FactoryBot.create(:user_project, :public, name: matched) }
        let!(:public_group_project) { FactoryBot.create(:group_project, :public, name: matched) }
        # 非公開プロジェクト
        let!(:private_user_project) { FactoryBot.create(:user_project, :private, name: matched) }
        # 削除済みプロジェクト
        let!(:deleted_user_project) { FactoryBot.create(:user_project, :soft_destroyed, name: matched) }
        # クエリと一致しないプロジェクト
        let!(:one_of_the_project) { FactoryBot.create(:user_project, :public, name: unmatched) }
      end

      context '完全一致' do
        include_context 'projects with name', 'sample', 'zample'
        include_examples '検索結果', 'sample'
      end

      context '部分一致' do
        include_context 'projects with name', 'foobar', 'foo'
        include_examples '検索結果', 'foo bar'
      end
    end

    describe 'Search projects by title' do
      shared_context 'projects with title' do |matched, unmatched|
        let!(:public_user_project) { FactoryBot.create(:user_project, :public, title: matched) }
        let!(:public_group_project) { FactoryBot.create(:group_project, :public, title: matched) }
        let!(:private_user_project) { FactoryBot.create(:user_project, :private, title: matched) }
        let!(:deleted_user_project) { FactoryBot.create(:user_project, :soft_destroyed, title: matched) }
        let!(:one_of_the_project) { FactoryBot.create(:user_project, :public, title: unmatched) }
      end

      context '完全一致' do
        include_context 'projects with title', 'sample', 'zample'
        include_examples '検索結果', 'sample'
      end

      context '部分一致' do
        include_context 'projects with title', 'foobar', 'foo'
        include_examples '検索結果', 'foo bar'
      end
    end

    describe 'Search projects by description' do
      shared_context 'projects with description' do |matched, unmatched|
        let!(:public_user_project) { FactoryBot.create(:user_project, :public, description: matched) }
        let!(:public_group_project) { FactoryBot.create(:group_project, :public, description: matched) }
        let!(:private_user_project) { FactoryBot.create(:user_project, :private, description: matched) }
        let!(:deleted_user_project) { FactoryBot.create(:user_project, :soft_destroyed, description: matched) }
        let!(:one_of_the_project) { FactoryBot.create(:user_project, :public, description: unmatched) }
      end

      context '完全一致' do
        include_context 'projects with description', 'sample', 'zample'
        include_examples '検索結果', 'sample'
      end

      context '部分一致' do
        include_context 'projects with description', 'foobar', 'foo'
        include_examples '検索結果', 'foo bar'
      end
    end

    describe 'Search projects by tag' do
      shared_context 'projects' do
        let!(:public_user_project) { FactoryBot.create(:user_project, :public) }
        let!(:public_group_project) { FactoryBot.create(:group_project, :public) }
        let!(:private_user_project) { FactoryBot.create(:user_project, :private) }
        let!(:deleted_user_project) { FactoryBot.create(:user_project, :soft_destroyed) }
        let!(:one_of_the_project) { FactoryBot.create(:user_project, :public) }
      end

      context '完全一致' do
        let!(:tag_hash) { FactoryBot.build(:tag, name: 'sample', user: FactoryBot.create(:user)).attributes }
        include_context 'projects'

        before do
          [public_user_project, public_group_project,
           private_user_project, deleted_user_project].each do |project|
            project.tags.create(tag_hash)
          end

          tag_hash['name'] = 'zample'
          one_of_the_project.tags.create(tag_hash)

          [public_user_project, public_group_project,
           private_user_project, deleted_user_project, one_of_the_project].each(&:update_draft!)
        end

        include_examples '検索結果', 'sample'
      end

      context '部分一致' do
        let!(:tag_hash) { FactoryBot.build(:tag, name: 'foobar', user: FactoryBot.create(:user)).attributes }
        include_context 'projects'

        before do
          [public_user_project, public_group_project,
           private_user_project, deleted_user_project].each do |project|
            project.tags.create(tag_hash)
          end

          tag_hash['name'] = 'foo'
          one_of_the_project.tags.create(tag_hash)

          [public_user_project, public_group_project,
           private_user_project, deleted_user_project, one_of_the_project].each(&:update_draft!)
        end

        include_examples '検索結果', 'foo bar'
      end
    end

    describe 'Search projects by project' do
      shared_context 'projects' do
        let!(:public_user_project) { FactoryBot.create(:user_project, :public) }
        let!(:public_group_project) { FactoryBot.create(:group_project, :public) }
        let!(:private_user_project) { FactoryBot.create(:user_project, :private) }
        let!(:deleted_user_project) { FactoryBot.create(:user_project, :soft_destroyed) }
        let!(:one_of_the_project) { FactoryBot.create(:user_project, :public) }
      end

      context '完全一致' do
        include_context 'projects'

        before do
          state_attributes = FactoryBot.attributes_for(:state, description: 'sample')
          [public_user_project, public_group_project,
           private_user_project, deleted_user_project].each do |project|
            project.states.create!(state_attributes)
          end

          state_attributes[:description] = 'zample'
          one_of_the_project.states.create!(state_attributes)

          [public_user_project, public_group_project,
           private_user_project, deleted_user_project, one_of_the_project].each do |project|
            project.update_draft!
          end
        end

        include_examples '検索結果', 'sample'
      end

      context '部分一致' do
        include_context 'projects'

        before do
          state_attributes = FactoryBot.attributes_for(:state, description: 'foobar')
          [public_user_project, public_group_project, private_user_project, deleted_user_project].each do |project|
            project.states.create!(state_attributes)
          end

          state_attributes[:description] = 'foo'
          one_of_the_project.states.create!(state_attributes)

          [public_user_project, public_group_project,
           private_user_project, deleted_user_project, one_of_the_project].each(&:update_draft!)
        end

        include_examples '検索結果', 'foo bar'
      end
    end

    shared_context 'projects with owner' do
      let!(:public_user_project) { FactoryBot.create(:user_project, :public, owner: user) }
      let!(:public_group_project) { FactoryBot.create(:group_project, :public, owner: group) }
      let!(:private_user_project) { FactoryBot.create(:user_project, :private, owner: user) }
      let!(:deleted_user_project) { FactoryBot.create(:user_project, :soft_destroyed, owner: user) }
      let!(:one_of_the_project) { FactoryBot.create(:user_project, :public, owner: one_of_the_users) }
    end

    describe 'Search projects by owner name' do
      let!(:user) { FactoryBot.create(:user, name: 'sample-user') }
      let!(:one_of_the_users) { FactoryBot.create(:user, name: 'one-of-the-users') }
      let!(:group) { FactoryBot.create(:group, name: 'sample-group') }

      include_context 'projects with owner'

      context '完全一致' do
        # userとgroupで名前が重複できないのでどちらか一方だけが返ってくる結果を期待する
        include_examples '検索結果(public user project only)', 'sample-user'
        include_examples '検索結果(public group project only)', 'sample-group'
      end

      context '部分一致' do
        include_examples '検索結果', 'sample'
      end
    end

    describe 'Search projects by url' do
      let!(:user) { FactoryBot.create(:user, url: 'https://sample.com') }
      let!(:one_of_the_users) { FactoryBot.create(:user, url: 'https://oneoftheusers.com') }
      let!(:group) { FactoryBot.create(:group, url: 'https://sample.com') }

      include_context 'projects with owner'

      context '完全一致' do
        include_examples '検索結果', 'https://sample.com'
      end

      context '部分一致' do
        include_examples '検索結果', 'sample'
      end
    end

    describe 'Search projects by location' do
      let!(:user) { FactoryBot.create(:user, location: 'Tokyo,Japan') }
      let!(:one_of_the_users) { FactoryBot.create(:user, location: 'Hachinohe,Japan') }
      let!(:group) { FactoryBot.create(:group, location: 'Tokyo,Japan') }

      include_context 'projects with owner'

      context '完全一致' do
        include_examples '検索結果', 'Tokyo,Japan'
      end

      context '部分一致' do
        include_examples '検索結果', 'Tokyo Japan'
      end
    end

    describe 'Search project by zenkaku-space or tab separated query' do
      shared_context 'projects with name' do |matched, unmatched|
        let!(:public_user_project) { FactoryBot.create(:user_project, :public, name: matched) }
        let!(:public_group_project) { FactoryBot.create(:group_project, :public, name: matched) }
        let!(:private_user_project) { FactoryBot.create(:user_project, :private, name: matched) }
        let!(:deleted_user_project) { FactoryBot.create(:user_project, :soft_destroyed, name: matched) }
        let!(:one_of_the_project) { FactoryBot.create(:user_project, :public, name: unmatched) }
      end

      context '部分一致' do
        include_context 'projects with name', 'foobar', 'foo'
        include_examples '検索結果', "foo　\tbar"
      end
    end
  end

  describe 'GET slideshow' do
    subject { get :slideshow, params: { owner_name: project.owner, project_id: project } }
    let(:project) { FactoryBot.create(:project) }
    it { is_expected.to be_successful }
  end
end
