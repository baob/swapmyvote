require "rails_helper"

RSpec.describe "AdminController", type: :controller do
  subject { AdminController.new }

  before do
    allow(ENV).to receive(:[])
    allow(ENV).to receive(:[]).with("ADMIN_PASSWORD").and_return("secret")
    allow(subject).to receive(:authenticate_or_request_with_http_basic) .with(anything).and_return true

    @controller = subject
  end

  include Devise::Test::ControllerHelpers

  describe "GET #stats" do
    it "returns http success" do
      get :stats
      expect(response).to have_http_status(:success)
    end
  end
end
