require "rails_helper"

require_relative '../../lib/modules/swap_success'

RSpec.describe SwapSuccess do

  describe ".order_keys_for_uniqueness" do
    let(:key1) { ['aaaa', 123] }
    let(:key2) { ['bbb', 456] }

    subject{ ->(x,y){ described_class.order_keys_for_uniqueness(x, y) } }

    it "maps key pairs in either order to the same thing" do
      expect(subject.call(key1, key2)).to eq(subject.call(key2, key1))
    end

    it "maps key pairs to one if the pair orderings" do
      expect([[key1, key2], [key2, key1]]).to include(subject.call(key1, key2))
      expect([[key1, key2], [key2, key1]]).to include(subject.call(key2, key1))
    end
  end

  describe ".score_conf_or_not_value" do

    context "overall ratio of succesful/confirmed swaps, to unconfirmed swaps is 8:1" do
      let(:ratio) { 8.0 }

      context "and we have 24 confirmed swaps and 0 unconfirmed in this group" do
        let(:value) do
          v = Hash.new
          v[true] = 24
          v[false] = 0
          v
        end
        specify { expect(described_class.score_conf_or_not_value(value,ratio)).to eq(2.0) }
      end

      context "and we have 0 confirmed swaps and 12 unconfirmed in this group" do
        let(:value) do
          v = Hash.new
          v[true] = 0
          v[false] = 12
          v
        end
        specify { expect(described_class.score_conf_or_not_value(value,ratio)).to eq(0.0) }
      end

      context "and we have 24 confirmed swaps and 3 unconfirmed in this group (the average ratio)" do
        let(:value) do
          v = Hash.new
          v[true] = 24
          v[false] = 3
          v
        end
        specify { expect(described_class.score_conf_or_not_value(value,ratio)).to eq(1.0) }
      end

    end

  end
end

