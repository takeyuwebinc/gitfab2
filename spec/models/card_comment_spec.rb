# frozen_string_literal: true

describe CardComment do
  describe '.for_project' do
    let(:project) { FactoryBot.create(:user_project) }
    let!(:target) { FactoryBot.create(:card_comment, card: FactoryBot.create(:note_card, project: project)) }
    let!(:other) { FactoryBot.create(:card_comment, card: FactoryBot.create(:note_card)) }

    it 'card 経由で指定プロジェクトのコメントのみ返すこと' do
      expect(CardComment.for_project(project.id)).to contain_exactly(target)
    end
  end
end
