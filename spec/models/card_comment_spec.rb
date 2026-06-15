# frozen_string_literal: true

describe CardComment do
  describe '.for_project' do
    let(:project) { FactoryBot.create(:user_project) }
    # project_id 列を直接持つカード（NoteCard）上のコメント
    let!(:on_note) { FactoryBot.create(:card_comment, card: FactoryBot.create(:note_card, project: project)) }
    # project_id 列を持たず state 経由でプロジェクトに紐づくカード（Annotation）上のコメント
    let!(:on_annotation) do
      FactoryBot.create(:card_comment,
                        card: FactoryBot.create(:annotation, state: FactoryBot.create(:state, :without_annotations, project: project)))
    end
    # 別プロジェクトのコメント
    let!(:other) { FactoryBot.create(:card_comment, card: FactoryBot.create(:note_card)) }

    it 'カードの所属プロジェクト（project_id 列・state 経由の両方）のコメントを返すこと' do
      expect(CardComment.for_project(project.id)).to contain_exactly(on_note, on_annotation)
    end

    it 'Annotation カード上のコメントは project_id 列が nil でも含まれること（表示・リンクの card.project と一致）' do
      expect(on_annotation.card.project_id).to be_nil
      expect(on_annotation.card.project.id).to eq project.id
      expect(CardComment.for_project(project.id)).to include(on_annotation)
    end
  end
end
