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
end

