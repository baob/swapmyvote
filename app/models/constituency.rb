class Constituency < ApplicationRecord
  has_many :polls

  def name_mapped_to_ons_name
    name.strip
  end
end
