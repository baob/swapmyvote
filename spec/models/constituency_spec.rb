require "rails_helper"

RSpec.describe Constituency, type: :model do
  subject { described_class.new(id: 1)}

  describe "#polls" do
    specify { expect {subject.polls}.not_to raise_error }
  end

  specify { expect(subject).to respond_to(:name) }
  specify { expect(subject).to respond_to(:name_mapped_to_ons_name) }

  ons_examples = {
    "Birmingham Ladywood" => "Birmingham, Ladywood",
    "Liverpool Hallam" => "Liverpool, Hallam",
    "Manchester Gorton" => "Manchester, Gorton",
    "Manchester Central" => "Manchester Central",
    "Sheffield Brightside and Hillsborough" => "Sheffield, Brightside and Hillsborough",
    "Sheffield Central" => "Sheffield Central",
    "Sheffield South East" => "Sheffield South East",
    "Brighton Kemptown" => "Brighton, Kemptown",
    "Plymouth Moorview" => "Plymouth, Moorview",
    "Southampton Test" => "Southampton, Test",
    "Ealing Southall" => "Ealing, Southall",
    "Ealing North" => "Ealing North",
    "Acton and Ealing Village" => "Acton and Ealing, Village",
    "Lewisham Deptford" => "Lewisham, Deptford",
    "Lewisham East" => "Lewisham East"
  }

  normalised_examples = {
    "Birmingham Ladywood" => "Birmingham Ladywood",
    "Liverpool Hallam" => "Liverpool Hallam",
    "Manchester Gorton" => "Manchester Gorton",
    "Manchester Central" => "Manchester Central",
    "Sheffield Central" => "Sheffield Central",
    "Sheffield South East" => "Sheffield South East",
    "Brighton Kemptown" => "Brighton Kemptown",
    "Plymouth Moorview" => "Plymouth Moorview",
    "Southampton Test" => "Southampton Test",
    "Ealing Southall" => "Ealing Southall",
    "Ealing North" => "Ealing North",
    "Acton and Ealing Village" => "Acton|Ealing Village",
    "Somewhere, SomewhereElse and Someplace" => "Somewhere|SomewhereElse|Someplace",
    "Lewisham Deptford" => "Lewisham Deptford",
    "Lewisham East" => "Lewisham East",
    "North Dorset" => "Dorset North",
    "North East Glasgow" => "Glasgow North East",
    "West Lancashire" => "Lancashire West",
    "South Norfolk" => "Norfolk South",
    "North West Hampshire" => "Hampshire North West",
    "South East Sheffield" => "Sheffield South East",
    "South West Hertfordshire" => "Hertfordshire South West",
    "East Hampshire" => "Hampshire East",
  }

  describe '#name_mapped_to_ons_name' do
    ons_examples.each do |(our_name, ons_name)|
      it "when given #{our_name}, returns #{ons_name}" do
        expect(described_class.new(name: our_name).name_mapped_to_ons_name).to eql(ons_name)
      end
    end
  end

  describe '#normalised_name' do
    normalised_examples.each do |(our_name, ons_name)|
      it "when given #{our_name}, returns #{ons_name}" do
        expect(described_class.new(name: our_name).normalised_name).to eql(ons_name)
      end
    end
  end
end
