FactoryBot.define do
  factory :sent_email do
    user { build(:user) }
    template { "MyString" }
  end
end
