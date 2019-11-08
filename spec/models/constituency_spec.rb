require "rails_helper"

RSpec.describe Constituency, type: :model do
  subject { described_class.new(id: 1)}

  describe "#polls" do
    specify { expect {subject.polls}.not_to raise_error }
  end

  specify { expect(subject).to respond_to(:name) }
  specify { expect(subject).to respond_to(:name_mapped_to_ons_name) }

  examples = {
    "Birmingham Ladywood" => "Birmingham, Ladywood",
    "Liverpool Hallam" => "Liverpool, Hallam",
    "Manchester Gorton" => "Manchester, Gorton",
    "Manchester Central" => "Manchester Central",
    "Sheffield Brightside and Hillsborough" => "Sheffield, Brightside and Hillsborough",
    "Brighton Kemptown" => "Brighton, Kemptown",
    "Plymouth Moorview" => "Plymouth, Moorview",
    "Southampton Test" => "Southampton, Test",
    "Ealing Southall" => "Ealing, Southall",
    "Lewisham Deptford" => "Lewisham, Deptford"
}


  describe '#name_mapped_to_ons_name' do
    examples.each do |(our_name, ons_name)|
      it "when given #{our_name}, returns #{ons_name}" do
        expect(described_class.new(name: our_name).name_mapped_to_ons_name).to eql(ons_name)
      end
    end
  end
end
