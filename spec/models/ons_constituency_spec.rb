require "rails_helper"

RSpec.describe OnsConstituency, type: :model do
  specify { expect(subject).to respond_to(:name) }
  specify { expect(subject).to respond_to(:ons_id) }
  specify { expect(subject).to respond_to(:normalised_name) }

  normalised_examples = {
    "Birmingham, Ladywood" => "Birmingham|Ladywood",
    "Liverpool, Hallam" => "Liverpool|Hallam",
    "Manchester, Gorton" => "Manchester|Gorton",
    "Manchester Central" => "Manchester Central",
    "Sheffield Central" => "Sheffield Central",
    "Brighton, Kemptown" => "Brighton|Kemptown",
    "Plymouth, Moorview" => "Plymouth|Moorview",
    "Southampton,Test" => "Southampton|Test",
    "Ealing, Southall" => "Ealing|Southall",
    "Ealing North" => "Ealing North",
    "Acton and Ealing Village" => "Acton|Ealing Village",
    "North Dorset" => "Dorset North",
    "North East Glasgow" => "Glasgow North East",
    "West Lancashire" => "Lancashire West",
    "South Norfolk" => "Norfolk South",
    "North West Hampshire" => "Hampshire North West",
    "South East Sheffield" => "Sheffield South East",
    "South West Hertfordshire" => "Hertfordshire South West",
    "East Hampshire" => "Hampshire East",
    "Sheffield, Brightside and Hillsborough" => "Sheffield|Brightside|Hillsborough",
    "City of Durham" => "Durham, City of"
  }

  describe "#normalised_name" do
    normalised_examples.each do |(our_name, ons_name)|
      it "when given #{our_name}, returns #{ons_name}" do
        expect(described_class.new(name: our_name).normalised_name).to eql(ons_name)
      end
    end
  end
end
