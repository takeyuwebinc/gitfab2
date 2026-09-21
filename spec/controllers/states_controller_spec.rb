# frozen_string_literal: true

describe StatesController, type: :controller do
  render_views

  describe 'GET new' do
    let(:project) { FactoryBot.create :user_project }

    before { sign_in project.owner }

    it do
      get :new, params: { owner_name: project.owner, project_id: project.name }, xhr: true
      expect(response).to render_template :_card_form
    end
  end

  describe 'GET show' do
    let(:project) { FactoryBot.create :user_project }
    let(:state) { FactoryBot.create(:state, project: project) }

    before { sign_in project.owner }
  
    it do
      get :show, params: { owner_name: project.owner, project_id: project.name, id: state.id }, xhr: true
      expect(response).to render_template :show, formats: :json
    end
  end

  describe 'GET edit' do
    let(:project) { FactoryBot.create :user_project }
    let(:state) { FactoryBot.create(:state, project: project) }

    before { sign_in(project.owner) }
  
    it do
      get :edit, params: { owner_name: project.owner, project_id: project, id: state }, xhr: true
      expect(response).to render_template :edit
    end
  end

  describe 'POST create' do
    let(:project) { FactoryBot.create :user_project }
  
    context 'when an owner is signed in' do
      let(:current_user) { project.owner }
      before { sign_in(current_user) }

      context 'with proper values' do
        it do
          post :create,
            params: {
              owner_name: project.owner, project_id: project,
              state: { type: Card::State.name, title: 'foo', description: 'bar' }
            },
            xhr: true
          expect(response).to have_http_status(:ok)
        end

        it do
          post :create,
            params: {
              owner_name: project.owner, project_id: project,
              state: { type: Card::State.name, title: 'foo', description: 'bar' }
            },
            xhr: true
          expect(response).to render_template :create
        end

        it 'has 1 state' do
          expect {
            post :create,
            params: {
              owner_name: project.owner, project_id: project,
              state: { type: Card::State.name, title: 'foo', description: 'bar' }
            },
            xhr: true
          }.to change(project.states, :count).by(1)
        end
      end

      context 'with invalid values' do
        it do
          post :create,
            params: {
              owner_name: project.owner, project_id: project,
              state: { type: '', title: 'foo', description: 'bar' }
            },
            xhr: true
          expect(response).to_not have_http_status(:ok)
        end

        it do
          post :create,
            params: {
              owner_name: project.owner, project_id: project,
              state: { type: '', title: 'foo', description: 'bar' }
            },
            xhr: true
          expect(JSON.parse(response.body, symbolize_names: true)).to eq({ success: false })
        end
      end

      context 'スパムキーワードを含む場合' do
        let!(:spam_keyword) { create(:spam_keyword, keyword: 'casino', enabled: true) }

        before { SpamKeywordDetector.clear_cache }
        after { SpamKeywordDetector.clear_cache }

        it 'タイトルにスパムキーワードを含む場合は拒否されること' do
          post :create,
            params: {
              owner_name: project.owner, project_id: project,
              state: { type: Card::State.name, title: 'Visit casino now', description: 'bar' }
            },
            xhr: true
          expect(response).to have_http_status(:unprocessable_entity)
          expect(JSON.parse(response.body, symbolize_names: true)[:error]).to include('prohibited keyword')
        end

        it '説明にスパムキーワードを含む場合は拒否されること' do
          post :create,
            params: {
              owner_name: project.owner, project_id: project,
              state: { type: Card::State.name, title: 'foo', description: 'Visit casino now' }
            },
            xhr: true
          expect(response).to have_http_status(:unprocessable_entity)
        end

        it 'Stateが作成されないこと' do
          expect {
            post :create,
              params: {
                owner_name: project.owner, project_id: project,
                state: { type: Card::State.name, title: 'Visit casino now', description: 'bar' }
              },
              xhr: true
          }.not_to change(project.states, :count)
        end
      end
    end

    context 'when an user is signed in' do
      let(:current_user) { FactoryBot.create(:user) }
      before { sign_in(current_user) }

      before do
        post :create,
          params: {
            owner_name: project.owner, project_id: project,
            state: { type: Card::State.name, title: 'foo', description: 'bar' }
          },
          xhr: true
        project.reload
      end
      it { expect(response).to_not have_http_status(:ok) }
    end

    context 'when an user is not signed in' do
      before do
        post :create,
          params: {
            owner_name: project.owner, project_id: project,
            state: { type: Card::State.name, title: 'foo', description: 'bar' }
          },
          xhr: true
        project.reload
      end
      it { expect(response).to_not have_http_status(:ok) }
    end
  end

  describe 'PATCH update' do
    let(:project) { FactoryBot.create :user_project }
    let(:state) { FactoryBot.create(:state, project: project) }

    context 'when an owner is signed in' do
      let(:current_user) { project.owner }
      before { sign_in(current_user) }

      it 'should have new title and new description' do
        patch :update,
          params: {
            owner_name: project.owner, project_id: project.id, id: state.id,
            state: { title: 'new_title', description: 'new_desc' }
          },
          xhr: true

        state.reload
        expect(state.title).to eq 'new_title'
        expect(state.description).to eq 'new_desc'
      end

      it do
        patch :update,
          params: {
            owner_name: project.owner, project_id: project.id, id: state.id,
            state: { title: 'new_title', description: 'new_desc' }
          },
          xhr: true
  
        expect(response).to have_http_status(:ok)
      end

      it do
        patch :update,
          params: {
            owner_name: project.owner, project_id: project.id, id: state.id,
            state: { title: 'new_title', description: 'new_desc' }
          },
          xhr: true

        expect(response).to render_template :update
      end
      
      context 'with invalid values' do
        it do
          patch :update,
            params: {
              owner_name: project.owner, project_id: project.id, id: state.id,
              state: { type: '', title: 'foo', description: 'bar' }
            },
            xhr: true
          expect(response).to_not have_http_status(:ok)
        end
        it do
          patch :update,
            params: {
              owner_name: project.owner, project_id: project.id, id: state.id,
              state: { type: '', title: 'foo', description: 'bar' }
            },
            xhr: true
          expect(JSON.parse(response.body, symbolize_names: true)).to eq({ success: false })
        end
      end

      context 'スパムキーワードを含む場合' do
        let!(:spam_keyword) { create(:spam_keyword, keyword: 'casino', enabled: true) }

        before { SpamKeywordDetector.clear_cache }
        after { SpamKeywordDetector.clear_cache }

        it 'タイトルにスパムキーワードを含む場合は拒否されること' do
          patch :update,
            params: {
              owner_name: project.owner, project_id: project.id, id: state.id,
              state: { title: 'Visit casino now', description: 'new_desc' }
            },
            xhr: true
          expect(response).to have_http_status(:unprocessable_entity)
          expect(JSON.parse(response.body, symbolize_names: true)[:error]).to include('prohibited keyword')
        end

        it '説明にスパムキーワードを含む場合は拒否されること' do
          patch :update,
            params: {
              owner_name: project.owner, project_id: project.id, id: state.id,
              state: { title: 'new_title', description: 'Visit casino now' }
            },
            xhr: true
          expect(response).to have_http_status(:unprocessable_entity)
        end

        it 'Stateが更新されないこと' do
          original_title = state.title
          patch :update,
            params: {
              owner_name: project.owner, project_id: project.id, id: state.id,
              state: { title: 'Visit casino now', description: 'new_desc' }
            },
            xhr: true
          state.reload
          expect(state.title).to eq(original_title)
        end
      end
    end

    context 'when an user is signed in' do
      let(:current_user) { FactoryBot.create(:user) }
      before { sign_in(current_user) }
  
      it do
        patch :update,
          params: {
            owner_name: project.owner, project_id: project.id, id: state.id,
            state: { title: 'new_title', description: 'new_desc' }
          },
          xhr: true
        expect(response).to_not have_http_status(:ok)
      end

      it do
        patch :update,
          params: {
            owner_name: project.owner, project_id: project.id, id: state.id,
            state: { title: 'new_title', description: 'new_desc' }
          },
          xhr: true
        expect(response).to_not render_template :update
      end
    end

    context 'when an user is not signed in' do
      let!(:state) { FactoryBot.create(:state, project: project) }

      it do
        patch :update,
          params: {
            owner_name: project.owner, project_id: project.id, id: state.id,
            state: { title: 'new_title', description: 'new_desc' }
          },
          xhr: true
        expect(response).to_not have_http_status(:ok) 
      end

      it do
        patch :update,
          params: {
            owner_name: project.owner, project_id: project.id, id: state.id,
            state: { title: 'new_title', description: 'new_desc' }
          },
          xhr: true
        expect(response).to_not render_template :update
      end
    end
  end

  describe 'PATCH update による Annotation の並べ替え' do
    let(:project) { FactoryBot.create(:user_project) }
    let!(:state) { travel_to(1.day.ago) { FactoryBot.create(:state, :without_annotations, project: project, title: 'state') } }
    let!(:annotations) do
      travel_to(1.day.ago) { Array.new(4) { |i| state.annotations.create!(title: "annotation #{i}") } }
    end
    # 更新通知の送り先。操作者自身には通知されない。
    let!(:collaborator) { FactoryBot.create(:collaboration, project: project).owner }
    let(:current_user) { project.owner }

    before do
      project.update_columns(updated_at: 1.day.ago)
      sign_in(current_user)
    end

    def update_state(state_attributes)
      patch :update,
        params: { owner_name: project.owner, project_id: project.id, id: state.id, state: state_attributes },
        xhr: true
    end

    # 並べ替えフォームは nested_form が振る一意な index をキーにして送る。
    def form_attributes_for(cards)
      cards.each_with_index.to_h { |card, i| ["1695290000#{i}", { id: card.id, position: i + 1 }] }
    end

    def displayed_ids
      Card::Annotation.where(state_id: state.id).order(:position, :id).pluck(:id)
    end

    def stored_positions
      Card::Annotation.where(state_id: state.id).order(:position, :id).pluck(:position)
    end

    def json_body
      JSON.parse(response.body, symbolize_names: true)
    end

    it '4 枚のうち 1 枚だけを動かすどの並べ替えでも成功し、保存後の並びが指定と一致する' do
      moves = (0...4).to_a.product((0...4).to_a).reject { |from, to| from == to }
      failures = moves.filter_map do |from, to|
        annotations.each_with_index { |annotation, i| annotation.update_columns(position: i + 1) }
        order = annotations.dup
        order.insert(to, order.delete_at(from))

        update_state(annotations_attributes: form_attributes_for(order))

        actual = [response.status, displayed_ids, stored_positions]
        expected = [200, order.map(&:id), [1, 2, 3, 4]]
        { move: [from, to], actual: actual } unless actual == expected
      end

      expect(failures).to eq []
    end

    it '4 枚の全順列のどの並べ替えでも、保存後の並びが指定と一致し、position が 1 からの連番になる' do
      failures = annotations.permutation.filter_map do |order|
        annotations.each_with_index { |annotation, i| annotation.update_columns(position: i + 1) }

        update_state(annotations_attributes: form_attributes_for(order))

        actual = [response.status, displayed_ids, stored_positions]
        expected = [200, order.map(&:id), [1, 2, 3, 4]]
        { requested: order.map(&:id), actual: actual } unless actual == expected
      end

      expect(failures).to eq []
    end

    it '応答は State の HTML を含む JSON で、操作者が contributor に加わり、プロジェクトの updated_at が更新され、更新通知が送られる' do
      expect {
        update_state(annotations_attributes: form_attributes_for(annotations.reverse))
      }.to change { project.reload.updated_at }
        .and change { Notification.where(notified: collaborator, notifier: current_user).count }.by(1)

      aggregate_failures do
        expect(response).to have_http_status(:ok)
        expect(json_body[:html]).to include(%(id="#{state.id}"))
        expect(state.reload.contributors).to include(current_user)
      end
    end

    it 'title と description が両方とも空の Annotation を含んでも成功する' do
      annotations[1].update_columns(title: nil, description: nil)
      update_state(annotations_attributes: form_attributes_for(annotations.reverse))
      expect([response.status, displayed_ids]).to eq [200, annotations.reverse.map(&:id)]
    end

    context '拒否されるリクエスト' do
      def unchanged_state
        [
          Card::Annotation.where(state_id: state.id).order(:id).pluck(:id, :position, :updated_at),
          Card::State.where(id: state.id).pluck(:title, :description, :updated_at),
          Contribution.where(card_id: state.id).count,
          Notification.count
        ]
      end

      it 'State に属さない Annotation の id を含むと 404 になり、何も書き込まれず、更新通知も送られない' do
        other_annotation = FactoryBot.create(:annotation)
        attributes = form_attributes_for(annotations.reverse + [other_annotation])

        expect { update_state(title: 'new title', annotations_attributes: attributes) }.not_to change { unchanged_state }
        expect(response).to have_http_status(:not_found)
      end

      ['', 'abc', '1.5'].each do |position|
        it "position が #{position.inspect} だと 400 になり、何も書き込まれず、更新通知も送られない" do
          attributes = form_attributes_for(annotations.reverse)
          attributes.values.last[:position] = position

          expect { update_state(title: 'new title', annotations_attributes: attributes) }.not_to change { unchanged_state }
          expect([response.status, json_body]).to eq [400, { success: false }]
        end
      end

      it 'annotations_attributes が index をキーにしない単一の Hash で届くと 400 になり、何も書き込まれない' do
        attributes = { id: annotations.first.id, position: 4 }

        expect { update_state(title: 'new title', annotations_attributes: attributes) }.not_to change { unchanged_state }
        expect([response.status, json_body]).to eq [400, { success: false }]
      end

      it 'State 自身が検証に通らない場合は 400 になり、Annotation の position は変わらない' do
        expect {
          update_state(title: '', description: '', annotations_attributes: form_attributes_for(annotations.reverse))
        }.not_to change { unchanged_state }
        expect([response.status, json_body]).to eq [400, { success: false }]
      end

      context 'State の title か description がスパムキーワードに当たる場合' do
        before do
          create(:spam_keyword, keyword: 'casino', enabled: true)
          SpamKeywordDetector.clear_cache
        end
        after { SpamKeywordDetector.clear_cache }

        it '422 になり、Annotation の position は変わらない' do
          expect {
            update_state(title: 'Visit casino now', annotations_attributes: form_attributes_for(annotations.reverse))
          }.not_to change { Card::Annotation.where(state_id: state.id).order(:id).pluck(:id, :position, :updated_at) }
          expect(response).to have_http_status(:unprocessable_entity)
        end
      end

      it 'State を管理できない利用者のリクエストは 401 になり、position は変わらない' do
        sign_in(FactoryBot.create(:user))

        expect { update_state(annotations_attributes: form_attributes_for(annotations.reverse)) }.not_to change { unchanged_state }
        expect(response).to have_http_status(:unauthorized)
      end

      it '読み取り専用モードでは 503 になり、position は変わらない' do
        allow(SystemSetting).to receive(:readonly_mode_enabled?).and_return(true)

        expect { update_state(annotations_attributes: form_attributes_for(annotations.reverse)) }.not_to change { unchanged_state }
        expect(response).to have_http_status(:service_unavailable)
      end
    end

    it 'annotations_attributes を含まない更新では、Annotation の position の重複や欠番はそのまま残る' do
      annotations.zip([2, 2, 5, 5]) { |annotation, position| annotation.update_columns(position: position) }

      expect { update_state(title: 'new title') }
        .not_to change { Card::Annotation.where(state_id: state.id).order(:id).pluck(:id, :position) }
      expect([response.status, state.reload.title]).to eq [200, 'new title']
    end

    context 'annotations_attributes に position を持たない組がある場合' do
      it 'その組は並べ替えの依頼に含めず、直前にあった「依頼に含まれる Annotation」の直後に置く' do
        # b は直前に依頼に含まれる a がある。position を 0 とみなす扱いなら b が先頭に来るため、見分けられる。
        a, b, c, d = annotations
        attributes = { '0' => { id: c.id, position: 1 }, '1' => { id: d.id, position: 2 }, '2' => { id: a.id, position: 3 }, '3' => { id: b.id } }

        update_state(annotations_attributes: attributes)

        expect([response.status, displayed_ids, stored_positions]).to eq [200, [c.id, d.id, a.id, b.id], [1, 2, 3, 4]]
      end

      it 'position を持つ組が 1 つもなければ並びを確定せず、position の重複や欠番もそのまま残る' do
        annotations.zip([2, 2, 5, 5]) { |annotation, position| annotation.update_columns(position: position) }

        expect { update_state(annotations_attributes: { '0' => { id: annotations.first.id } }) }
          .not_to change { Card::Annotation.where(state_id: state.id).order(:id).pluck(:id, :position) }
        expect(response).to have_http_status(:ok)
      end
    end

    it '並べ替えと同時に送った Annotation の position 以外の属性は保存される' do
      a, b, c, d = annotations
      attributes = form_attributes_for([d, c, b, a])
      attributes.values.last[:title] = 'renamed'

      update_state(annotations_attributes: attributes)

      expect([response.status, displayed_ids, a.reload.title]).to eq [200, [d, c, b, a].map(&:id), 'renamed']
    end

    it 'State の保存の後に並びの確定で例外が起きると、State の属性と contributor の追加も取り消され、更新通知は送られない' do
      allow_any_instance_of(Card::Annotation).to receive(:update_columns).and_raise(ActiveRecord::StatementInvalid, 'write failed')
      before = [
        Card::Annotation.where(state_id: state.id).order(:id).pluck(:id, :position, :updated_at),
        Card::State.where(id: state.id).pluck(:title, :updated_at),
        Contribution.where(card_id: state.id).count,
        Notification.count
      ]

      update_state(title: 'new title', annotations_attributes: form_attributes_for(annotations.reverse))

      after = [
        Card::Annotation.where(state_id: state.id).order(:id).pluck(:id, :position, :updated_at),
        Card::State.where(id: state.id).pluck(:title, :updated_at),
        Contribution.where(card_id: state.id).count,
        Notification.count
      ]
      expect([response.status, after]).to eq [500, before]
    end

    context 'スパムの Annotation を含む State で、画面に出る Annotation だけを送る場合' do
      # 画面に出る 3 枚を逆順に並べ替える。スパムは直前にあった「送られた Annotation」の直後に残り、
      # 直前になければ先頭に残る。
      {
        0 => %i[spam c b a],
        1 => %i[c b a spam],
        2 => %i[c b spam a],
        3 => %i[c spam b a]
      }.each do |spam_index, expected_labels|
        it "スパムが #{spam_index + 1} 枚目にあるとき、全体が #{expected_labels.inspect} の順で 1 からの連番になる" do
          spam = annotations[spam_index]
          spam.update_columns(status: Card::Annotation.statuses[:spam])
          a, b, c = annotations - [spam]
          labels = { a.id => :a, b.id => :b, c.id => :c, spam.id => :spam }

          update_state(annotations_attributes: form_attributes_for([c, b, a]))

          aggregate_failures do
            expect(response).to have_http_status(:ok)
            expect(state.reload.visible_annotations.map(&:id)).to eq [c, b, a].map(&:id)
            expect([displayed_ids.map(&labels), stored_positions]).to eq [expected_labels, [1, 2, 3, 4]]
          end
        end
      end
    end
  end

  describe 'DELETE destroy' do
    let(:project) { FactoryBot.create :user_project }
    let(:state) { FactoryBot.create(:state, project: project) }
  
    context 'when an owner is signed in' do
      let(:current_user) { project.owner }
      before { sign_in(current_user) }

      context 'by who can manage the state' do
        it do
          delete :destroy,params: { owner_name: project.owner, project_id: project.name, id: state.id }, xhr: true
          expect(response).to have_http_status(:ok)
        end

        it do
          delete :destroy,params: { owner_name: project.owner, project_id: project.name, id: state.id }, xhr: true
          expect(JSON.parse(response.body, symbolize_names: true)).to eq({ success: true })
        end
      end
    end

    context 'when a user is signed in' do
      let(:current_user) { FactoryBot.create(:user) }
      before { sign_in(current_user) }

      context 'by who can manage the state' do
        it do
          delete :destroy,params: { owner_name: project.owner, project_id: project.name, id: state.id }, xhr: true
          expect(response).to_not have_http_status(:ok)
        end
      end
    end

    context 'when a user is not signed in' do
      context 'by who can manage the state' do
        it do
          delete :destroy,params: { owner_name: project.owner, project_id: project.name, id: state.id }, xhr: true
          expect(response).to_not have_http_status(:ok)
        end
      end
    end
  end

  describe 'POST to_annotation' do
    let(:project) { FactoryBot.create :user_project }
    let!(:state) { FactoryBot.create(:state, project: project) }
    let!(:state_2) { FactoryBot.create(:state, project: project) }

    context 'when an owner is signed in' do
      let(:current_user) { project.owner }

      before { sign_in(current_user) }

      it do
        post :to_annotation,
          params: { owner_name: project.owner, project_id: project.name, state_id: state_2.id, dst_state_id: state.id },
          xhr: true
        expect(response).to have_http_status(:ok)
      end

      it 'creates an annotation from a state' do
        expect {
          post :to_annotation,
            params: { owner_name: project.owner, project_id: project.name, state_id: state_2.id, dst_state_id: state.id },
            xhr: true
        }.to change(project.states, :count).by(-1)
      end

      it 'creates an annotation from a state' do
        expect {
          post :to_annotation,
            params: { owner_name: project.owner, project_id: project.name, state_id: state_2.id, dst_state_id: state.id },
            xhr: true
        }.to change(state.annotations, :count).by(1)
      end

      context '変換先に変換元自身を指定した場合' do
        let(:params) do
          { owner_name: project.owner, project_id: project.name, state_id: state_2.id, dst_state_id: state_2.id }
        end

        it 'returns 422 with an error message' do
          post :to_annotation, params: params, xhr: true

          expect(response).to have_http_status(:unprocessable_entity)
          body = JSON.parse(response.body, symbolize_names: true)
          expect(body[:success]).to eq(false)
          expect(body[:error]).to include('Cannot convert to the selected state')
        end

        it 'does not convert the state' do
          expect {
            post :to_annotation, params: params, xhr: true
          }.to_not change { state_2.reload.attributes.slice('type', 'state_id', 'position') }
        end

        it 'does not change states_count' do
          expect {
            post :to_annotation, params: params, xhr: true
          }.to_not change { project.reload.states_count }
        end
      end

      context '変換先が存在しない、または別プロジェクトの State の場合' do
        let(:other_project) { FactoryBot.create :user_project }
        let!(:other_state) { FactoryBot.create(:state, project: other_project) }

        it '存在しない id では 404 が返り、State が変わらないこと' do
          expect {
            post :to_annotation,
              params: { owner_name: project.owner, project_id: project.name, state_id: state_2.id, dst_state_id: 0 },
              xhr: true
          }.to_not change { state_2.reload.attributes.slice('type', 'state_id', 'position') }

          expect(response).to have_http_status(:not_found)
        end

        it '別プロジェクトの State では 404 が返り、State が変わらないこと' do
          expect {
            post :to_annotation,
              params: { owner_name: project.owner, project_id: project.name, state_id: state_2.id, dst_state_id: other_state.id },
              xhr: true
          }.to_not change { state_2.reload.attributes.slice('type', 'state_id', 'position') }

          expect(response).to have_http_status(:not_found)
        end
      end
    end

    context 'when a user is signed in' do
      let(:current_user) { FactoryBot.create(:user) }

      before { sign_in(current_user) }

      it do
        post :to_annotation,
          params: { owner_name: project.owner, project_id: project.name, state_id: state_2.id, dst_state_id: state.id },
          xhr: true
        expect(response).to_not have_http_status(:ok)
      end
    end

    context 'when a user is not signed in' do
      it do
        post :to_annotation,
          params: { owner_name: project.owner, project_id: project.name, state_id: state_2.id, dst_state_id: state.id },
          xhr: true

        expect(response).to_not have_http_status(:ok)
      end
    end
  end

  describe 'readonly mode restriction' do
    let(:project) { FactoryBot.create(:user_project) }
    let(:state) { FactoryBot.create(:state, project: project) }

    before do
      sign_in project.owner
      allow(SystemSetting).to receive(:readonly_mode_enabled?).and_return(true)
    end

    describe 'POST create' do
      it 'does not create a state' do
        expect {
          post :create,
            params: {
              owner_name: project.owner, project_id: project,
              state: { type: Card::State.name, title: 'foo', description: 'bar' }
            },
            xhr: true
        }.not_to change(project.states, :count)
      end

      it 'returns 503' do
        post :create,
          params: {
            owner_name: project.owner, project_id: project,
            state: { type: Card::State.name, title: 'foo', description: 'bar' }
          },
          xhr: true
        expect(response).to have_http_status(:service_unavailable)
      end
    end

    describe 'PATCH update' do
      it 'does not update the state' do
        original_title = state.title
        patch :update,
          params: {
            owner_name: project.owner, project_id: project.id, id: state.id,
            state: { title: 'new_title', description: 'new_desc' }
          },
          xhr: true
        expect(state.reload.title).to eq(original_title)
      end

      it 'returns 503' do
        patch :update,
          params: {
            owner_name: project.owner, project_id: project.id, id: state.id,
            state: { title: 'new_title', description: 'new_desc' }
          },
          xhr: true
        expect(response).to have_http_status(:service_unavailable)
      end
    end

    describe 'DELETE destroy' do
      it 'does not delete the state' do
        state # create it first
        expect {
          delete :destroy,
            params: { owner_name: project.owner, project_id: project.name, id: state.id },
            xhr: true
        }.not_to change(Card::State, :count)
      end

      it 'returns 503' do
        delete :destroy,
          params: { owner_name: project.owner, project_id: project.name, id: state.id },
          xhr: true
        expect(response).to have_http_status(:service_unavailable)
      end
    end

    describe 'POST to_annotation' do
      let!(:state2) { FactoryBot.create(:state, project: project) }

      it 'does not convert state to annotation' do
        expect {
          post :to_annotation,
            params: { owner_name: project.owner, project_id: project.name, state_id: state2.id, dst_state_id: state.id },
            xhr: true
        }.not_to change(state.annotations, :count)
      end

      it 'returns 503' do
        post :to_annotation,
          params: { owner_name: project.owner, project_id: project.name, state_id: state2.id, dst_state_id: state.id },
          xhr: true
        expect(response).to have_http_status(:service_unavailable)
      end
    end
  end
end
