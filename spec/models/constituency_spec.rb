require "rails_helper"

RSpec.describe Constituency, type: :model do
  subject { described_class.new(id: 1)}

  describe "#polls" do
    specify { expect {subject.polls}.not_to raise_error }
  end

  specify { expect(subject).to respond_to(:name) }
  specify { expect(subject).to respond_to(:normalised_name) }

  normalised_examples = {
    "Birmingham Ladywood" => "Birmingham|Ladywood",
    "Liverpool Hallam" => "Liverpool|Hallam",
    "Manchester Gorton" => "Manchester|Gorton",
    "Manchester Central" => "Manchester Central",
    "Sheffield Central" => "Sheffield Central",
    "Sheffield South East" => "Sheffield South East",
    "Brighton Kemptown" => "Brighton|Kemptown",
    "Plymouth Moorview" => "Plymouth|Moorview",
    "Southampton Test" => "Southampton|Test",
    "Ealing Southall" => "Ealing|Southall",
    "Ealing North" => "Ealing North",
    "Acton and Ealing Village" => "Acton|Ealing Village",
    "Sheffield, Brightside and Hillsborough" => "Sheffield|Brightside|Hillsborough",
    "Coatbridge, Chryston and Bellshill" => "Coatbridge|Chryston|Bellshill",
    "Lewisham Deptford" => "Lewisham|Deptford",
    "Lewisham East" => "Lewisham East",
    "North Dorset" => "Dorset North",
    "North East Glasgow" => "Glasgow North East",
    "West Lancashire" => "Lancashire West",
    "South Norfolk" => "Norfolk South",
    "North West Hampshire" => "Hampshire North West",
    "South East Sheffield" => "Sheffield South East",
    "South West Hertfordshire" => "Hertfordshire South West",
    "East Hampshire" => "Hampshire East",
    "Durham, City of" => "Durham, City of"
  }

  describe "#normalised_name" do
    normalised_examples.each do |(our_name, ons_name)|
      it "when given #{our_name}, returns #{ons_name}" do
        expect(described_class.new(name: our_name).normalised_name).to eql(ons_name)
      end
    end
  end
end
