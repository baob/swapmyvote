class OnsConstituency < ApplicationRecord
  COMPASS_PARTS = [
    "North East",
    "North West",
    "South East",
    "South West",
    "North",
    "East",
    "West",
    "South",
    "Central"
  ]
  CITY_PART = /^City of /

  def normalised_name
    name_first_word = name.gsub(",", "").split(" ").first
    return name if name == name_first_word

    name_parts = []
    remainder = name

    remainder_split_by_and = remainder.match(/^(.*) and (.*)$/)

    if remainder_split_by_and.nil?
      name_parts += remainder.split(",").map(&:strip)
    else
      name_parts = name_parts +
        remainder_split_by_and.captures.first.split(",").map(&:strip) +
        [remainder_split_by_and.captures.last]
    end

    name_parts.select{ |p| p != "" }.map{ |n| single_name_mapped_to_normalised_name(n) }.join("|")
  end

  private

  def single_name_mapped_to_normalised_name(single_name)
    compass_part = COMPASS_PARTS.detect{ |cp| single_name =~ / #{cp}$/ || single_name =~ /^#{cp} / }
    # puts "COMPASS PART #{compass_part} detected"
    unless compass_part.nil?
      non_compass_part = single_name.gsub(compass_part, "").gsub("  ", " ").strip
      return "#{non_compass_part} #{compass_part}"
    end

    is_city = single_name =~ CITY_PART
    if is_city
      return single_name.gsub(CITY_PART, "") + ", City of"
    end

    single_name
  end
end
