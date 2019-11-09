class Constituency < ApplicationRecord
  has_many :polls

  SUBDIVIDED_CITIES = %w[
    Birmingham
    Liverpool
    Sheffield
    Manchester
    Plymouth
    Brighton
    Southampton
    Ealing
    Lewisham
  ]

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

  def normalised_name
    name_first_word = name.gsub(",", "").split(" ").first
    after_first_word = name.gsub(",", "").split(" ")[1..-1].join(" ")
    return name if name == name_first_word

    if SUBDIVIDED_CITIES.include?(name_first_word)
      compass_part = COMPASS_PARTS.detect{ |cp| after_first_word =~ /^#{cp} / || after_first_word =~ /^#{cp}$/ }
      if compass_part
        name_parts = ["#{name_first_word} #{compass_part}"]
        remainder = after_first_word.gsub(compass_part, "")
      else
        name_parts = [name_first_word]
        remainder = after_first_word
      end
    else
      name_parts = []
      remainder = name.gsub(",", "")
    end

    remainder_split_by_and = remainder.match(/^(.*) and (.*)$/)

    if remainder_split_by_and.nil?
      name_parts << remainder
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
    unless compass_part.nil?
      # puts "COMPASS PART #{compass_part} detected"
      return single_name.gsub(compass_part, "").strip + " #{compass_part}"
    end

    # return single_name if single_name == "#{name_first_word} Central"

    single_name
  end
end
