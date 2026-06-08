# frozen_string_literal: true

RSpec.describe Admin::DashboardController, type: :controller do
  render_views

  let(:user) { create(:user, authority: "admin") }

  before { sign_in user }

  describe "GET #index" do
    it "成功すること" do
      get :index
      expect(response).to be_successful
    end

    it "上部ナビゲーションバーと管理ダッシュボードへの戻りリンクを表示すること" do
      get :index
      expect(response.body).to include('id="admin-nav"')
      expect(response.body).to include("管理ダッシュボード")
    end

    it "全14セクションへのリンクを表示すること" do
      get :index
      [
        admin_features_path,
        admin_projects_path,
        admin_background_path,
        admin_black_lists_path,
        admin_project_comments_path,
        admin_card_comments_path,
        admin_usages_path,
        admin_annotations_path,
        admin_tags_path,
        admin_spammers_path,
        admin_spam_keywords_path,
        admin_spam_detection_logs_path,
        admin_announcements_path,
        edit_admin_system_settings_path
      ].each do |path|
        expect(response.body).to include(path)
      end
    end

    context "without authority" do
      let(:user) { create(:user) }

      it "root に戻すこと" do
        get :index
        expect(response).to redirect_to(root_path)
      end
    end
  end
end
