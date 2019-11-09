require 'rails_helper'

RSpec.describe OnsConstituency, type: :model do
  specify { expect(subject).to respond_to(:name) }
  specify { expect(subject).to respond_to(:ons_id) }
  specify { expect(subject).to respond_to(:normalised_name) }
end
