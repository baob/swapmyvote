require "rails_helper"

RSpec.describe Poll, type: :model do
  describe "#constituency" do
    context "with poll with no constituency id" do
      let(:no_constituency_poll) { described_class.new(votes: 987) }

      it "is nil" do
        expect(no_constituency_poll.constituency).to be_nil
      end
    end

    context "with poll with constituency id" do
      let(:constituency) { OnsConstituency.create!(name: "test con 2 for polls", ons_id: "a-fake-ons-id") }
      let(:poll) { described_class.new(votes: 654, constituency_ons_id: constituency.ons_id) }

      it "is expected constituency" do
        expect(poll.constituency).to eq(constituency)
      end
    end
  end

  describe ".calculate_marginal_score" do
    it "finds all constituencies" do
      expect(OnsConstituency).to receive(:all).and_return(double.as_null_object)
      described_class.calculate_marginal_score
    end

    context "on a single constituency, split 32.56%, 27.31%, 19.43%" do
      before { allow(OnsConstituency).to receive(:all).and_return(constituencies) }

      let(:constituencies) { [constituency1] }
      let(:constituency1) { build(:ons_constituency, polls: [poll1, poll2, poll3]) }
      let(:poll1) { build(:poll, id: 12, votes: 3256) }
      let(:poll2) { build(:poll, id: 13, votes: 2731) }
      let(:poll3) { build(:poll, id: 14, votes: 1943) }

      describe "poll with 3256 votes" do
        specify do
          expect(poll1).to receive(:update).with(marginal_score: (poll1.votes - poll2.votes))
          described_class.calculate_marginal_score
        end
      end

      describe "poll with 2731 votes" do
        specify do
          expect(poll2).to receive(:update).with(marginal_score: (poll1.votes - poll2.votes))
          described_class.calculate_marginal_score
        end
      end

      describe "poll with 1943 votes" do
        specify do
          expect(poll3).to receive(:update).with(marginal_score: (poll1.votes - poll3.votes))
          described_class.calculate_marginal_score
        end
      end
    end
  end

  describe "#effort_to_win" do

    context "on a single constituency, split 32.56%, 27.31%, 19.43%" do

      let(:constituency1) { build(:ons_constituency) }
      let(:poll1) { build(:poll, id: 12, votes: 3256, party_id: 22, constituency: constituency1) }
      let(:poll2) { build(:poll, id: 13, votes: 2731, party_id: 23, constituency: constituency1) }
      let(:poll3) { build(:poll, id: 14, votes: 1943, party_id: 24, constituency: constituency1) }

      before do
        # there's probably a way to avoid this mock by using a cleverer factory
        allow(constituency1).to receive(:polls).and_return([poll1, poll2, poll3])
      end

      context "with one party to beat" do
        specify { expect(poll2.effort_to_win*2).to eq(poll1.votes - poll2.votes) }
      end
      context "with two parties to beat" do
        specify { expect(poll3.effort_to_win*2).to eq(poll1.votes - poll3.votes) }
      end
    end
  end
end
