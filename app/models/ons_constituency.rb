class OnsConstituency < ApplicationRecord
  COMPASS_PARTS = [
    "North East",
    "North West",
    "South East",
    "South West",
    "North",
    "East",
    "West",
    "South"
  ]

  def normalised_name
    name_split_by_and = name.match(/^(.*) and (.*)$/)
    return single_name_mapped_to_normalised_name(name) if name_split_by_and.nil?
    # puts "MULTIPLE NAME DETECTED #{name}"
    name_split_by_and.captures.map{ |n| single_name_mapped_to_normalised_name(n) }.join("|")
  end

  private

  def single_name_mapped_to_normalised_name(single_name)
    compass_part = COMPASS_PARTS.detect{ |cp| single_name =~ Regexp.new(cp) }
    # puts "COMPASS PART #{compass_part} detected"
    unless compass_part.nil?
      non_compass_part = single_name.gsub(compass_part, "").gsub("  ", " ").strip
      return "#{non_compass_part} #{compass_part}"
    end

    single_name
  end
end
