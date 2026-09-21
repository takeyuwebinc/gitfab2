# frozen_string_literal: true

describe Card do
  describe '並べ替え' do
    let(:project) { FactoryBot.create(:project) }

    # position を指定して State を作る。作成時のコールバックが振る position ではなく、
    # 本番に実在する重複・欠番の形を再現するため、作成後に列単位で書き込む。
    def create_states(positions)
      positions.map.with_index do |position, i|
        project.states.create!(description: "state #{i}").tap { |state| state.update_columns(position: position) }
      end
    end

    def reset_positions(cards, positions)
      cards.zip(positions) { |card, position| card.update_columns(position: position) }
    end

    def displayed_ids
      Card::State.where(project_id: project.id).order(:position, :id).pluck(:id)
    end

    def stored_positions
      Card::State.where(project_id: project.id).order(:position, :id).pluck(:position)
    end

    def snapshot
      Card::State.where(project_id: project.id).order(:id).pluck(:id, :position, :updated_at)
    end

    # 画面は並べ替え後の並びに 1 から順の position を振って送る。
    def request_for(cards)
      cards.each_with_index.map { |card, i| { id: card.id, position: i + 1 } }
    end

    describe '.rearrange!' do
      [3, 4, 5].each do |count|
        it "position が連番の #{count} 枚で、全順列のどの並びも指定どおりになり、position が 1 からの連番になる" do
          states = create_states((1..count).to_a)
          failures = states.permutation.filter_map do |order|
            reset_positions(states, (1..count).to_a)
            project.states.rearrange!(request_for(order))
            actual = [displayed_ids, stored_positions]
            expected = [order.map(&:id), (1..count).to_a]
            { requested: order.map(&:id), actual: actual } unless actual == expected
          end

          expect(failures).to eq []
        end
      end

      it 'position が変わったカードだけ updated_at が更新される' do
        a, b, c, d = travel_to(1.day.ago) { create_states([1, 2, 3, 4]) }
        before = snapshot.to_h { |id, _, updated_at| [id, updated_at] }

        project.states.rearrange!(request_for([a, c, b, d]))

        aggregate_failures do
          expect(a.reload.updated_at).to eq before[a.id]
          expect(d.reload.updated_at).to eq before[d.id]
          expect(b.reload.updated_at).to be_within(1.second).of(Time.current)
          expect(c.reload.updated_at).to be_within(1.second).of(Time.current)
        end
      end

      it '書き込みの途中で例外が起きると、その回の書き込みはすべて取り消される' do
        a, b, c = create_states([1, 2, 3])
        before = snapshot
        writes = 0
        allow_any_instance_of(Card::State).to receive(:update_columns).and_wrap_original do |original, *args|
          writes += 1
          raise ActiveRecord::StatementInvalid, 'write failed' if writes == 2

          original.call(*args)
        end

        expect { project.states.rearrange!(request_for([c, b, a])) }.to raise_error(ActiveRecord::StatementInvalid)
        expect(writes).to eq 2
        expect(snapshot).to eq before
      end

      context '境界' do
        it 'カードが 1 枚なら、その position が 1 になる' do
          state, = create_states([5])
          project.states.rearrange!([{ id: state.id, position: 7 }])
          expect(state.reload.position).to eq 1
        end

        it '複数のカードに同じ position を指定すると、現在の表示順が先のカードが前になる' do
          a, b, c = create_states([1, 2, 3])
          project.states.rearrange!([{ id: a.id, position: 2 }, { id: c.id, position: 1 }, { id: b.id, position: 1 }])
          expect([displayed_ids, stored_positions]).to eq [[b.id, c.id, a.id], [1, 2, 3]]
        end

        it '負の整数と 0 を並びのキーとして受け付ける' do
          a, b, c = create_states([1, 2, 3])
          project.states.rearrange!([{ id: a.id, position: '0' }, { id: b.id, position: -1 }, { id: c.id, position: '-2' }])
          expect([displayed_ids, stored_positions]).to eq [[c.id, b.id, a.id], [1, 2, 3]]
        end

        it 'index をキーにした Hash の形（フォームが送る nested attributes の形）も受け付ける' do
          a, b, c = create_states([1, 2, 3])
          project.states.rearrange!(
            '1695290000000' => { 'id' => c.id.to_s, 'position' => '1' },
            '1695290000001' => { 'id' => a.id.to_s, 'position' => '2' },
            '1695290000002' => { 'id' => b.id.to_s, 'position' => '3' }
          )
          expect([displayed_ids, stored_positions]).to eq [[c.id, a.id, b.id], [1, 2, 3]]
        end
      end

      context 'position に重複や欠番がある範囲' do
        # 本番の読み取り調査（2026-09-21）で実在した形。
        [
          [1, 2, 3, 5, 6, 6, 7],
          [2, 2, 3, 4, 5, 6, 7],
          [1, 1, 2, 2, 3, 3, 4, 5, 6],
          [1, 2, 3, 5, 6, 7, 8, 9, 10, 11, 11],
          [1, 2, 3, 4, 5, 6, 6, 6, 8, 10, 12, 12, 13, 14, 15, 16, 18, 18]
        ].each do |positions|
          it "#{positions.inspect} から、1 枚だけ動かす並べ替えと無作為な並べ替えのどちらでも指定どおりになる" do
            states = create_states(positions)
            original = states.sort_by { |state| [state.position, state.id] }
            rng = Random.new(20_260_921)
            orders = Array.new(10) do
              moved = original.dup
              moved.insert(rng.rand(moved.size), moved.delete_at(rng.rand(moved.size)))
            end
            orders += Array.new(10) { original.shuffle(random: rng) }

            failures = orders.filter_map do |order|
              reset_positions(states, positions)
              project.states.rearrange!(request_for(order))
              actual = [displayed_ids, stored_positions]
              expected = [order.map(&:id), (1..positions.size).to_a]
              { requested: order.map(&:id), actual: actual } unless actual == expected
            end

            expect(failures).to eq []
          end
        end
      end

      context 'リクエストに含まれないカードがある範囲' do
        it '現在の表示順で直前にあった「リクエストに含まれるカード」の直後に置かれ、直前になければ先頭に置かれる' do
          # z は y より id が大きいが、表示順では y より前にある。同じ場所に置くカードが
          # id 順ではなく表示順を保つことを見分けるため。
          x, a, y, z, b, c = create_states([1, 2, 4, 3, 5, 6])
          project.states.rearrange!([{ id: b.id, position: 1 }, { id: c.id, position: 2 }, { id: a.id, position: 3 }])
          expect([displayed_ids, stored_positions]).to eq [[x.id, b.id, c.id, a.id, z.id, y.id], [1, 2, 3, 4, 5, 6]]
        end

        it 'title と description が両方とも空のカードを含む範囲でも、そのカードを動かして確定できる' do
          a, empty, b = create_states([1, 2, 3])
          empty.update_columns(title: nil, description: nil)
          project.states.rearrange!([{ id: b.id, position: 1 }, { id: a.id, position: 2 }, { id: empty.id, position: 3 }])
          expect([displayed_ids, stored_positions]).to eq [[b.id, a.id, empty.id], [1, 2, 3]]
        end
      end
    end

    shared_examples '受け付けられない依頼を拒否する' do |method_name|
      let(:arrangement_method) { method_name }
      let!(:states) { travel_to(1.day.ago) { create_states([1, 2, 3]) } }
      let(:a) { states[0] }
      let(:b) { states[1] }
      let(:c) { states[2] }

      def expect_rejected(request, error)
        before = snapshot
        expect { project.states.public_send(arrangement_method, request) }.to raise_error(error)
        expect(snapshot).to eq before
      end

      it '範囲に属さない id を含むと「見つからない」として拒否し、何も書き込まない' do
        other_state = FactoryBot.create(:state, :without_annotations)
        expect_rejected(
          [{ id: c.id, position: 1 }, { id: b.id, position: 2 }, { id: other_state.id, position: 3 }],
          ActiveRecord::RecordNotFound
        )
      end

      it '存在しない id を含むと「見つからない」として拒否し、何も書き込まない' do
        expect_rejected([{ id: c.id, position: 1 }, { id: 0, position: 2 }], ActiveRecord::RecordNotFound)
      end

      ['', nil, '1.5', 1.5, 'abc', '1a'].each do |position|
        it "position が #{position.inspect} だと「不正なリクエスト」として拒否し、何も書き込まない" do
          expect_rejected([{ id: c.id, position: 1 }, { id: a.id, position: position }], Card::InvalidArrangement)
        end
      end

      it 'position を持たない組を含むと「不正なリクエスト」として拒否し、何も書き込まない' do
        expect_rejected([{ id: c.id, position: 1 }, { id: a.id }], Card::InvalidArrangement)
      end

      it 'id を持たない組を含むと「不正なリクエスト」として拒否し、何も書き込まない' do
        expect_rejected([{ id: c.id, position: 1 }, { position: 2 }], Card::InvalidArrangement)
      end

      it '同じ id を複数回含むと「不正なリクエスト」として拒否し、何も書き込まない' do
        expect_rejected(
          [{ id: c.id, position: 1 }, { id: a.id, position: 2 }, { id: c.id, position: 3 }],
          Card::InvalidArrangement
        )
      end
    end

    describe '.rearrange! の拒否' do
      it_behaves_like '受け付けられない依頼を拒否する', :rearrange!
    end

    describe '.verify_arrangement!' do
      it_behaves_like '受け付けられない依頼を拒否する', :verify_arrangement!

      it '受け付けられる依頼でも何も書き込まない' do
        a, b, c = create_states([1, 2, 3])
        before = snapshot
        project.states.verify_arrangement!(request_for([c, b, a]))
        expect(snapshot).to eq before
      end
    end
  end
end
