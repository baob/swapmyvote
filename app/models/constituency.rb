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
    "South"
  ]

  def name_mapped_to_ons_name
    name_split_by_and = name.match(/^(.*) and (.*)$/)
    return single_name_mapped_to_ons_name(name) if name_split_by_and.nil?
    name_split_by_and.captures.map{ |n| single_name_mapped_to_ons_name(n) }.join(" and ")
  end

  def normalised_name
    name_split_by_and = name.match(/^(.*) and (.*)$/)
    return single_name_mapped_to_normalised_name(name) if name_split_by_and.nil?
    name_parts = name_split_by_and.captures.first.split(",").map(&:strip) + [name_split_by_and.captures.last]
    name_parts.map{ |n| single_name_mapped_to_normalised_name(n) }.join("|")
  end

  private

  def single_name_mapped_to_ons_name(single_name)
    name_first_word = single_name.strip.split(" ").first
    compass_part = COMPASS_PARTS.detect{ |cp| "#{name_first_word} #{cp}" == single_name }
    return single_name unless compass_part.nil?
    return single_name if single_name == name_first_word
    return single_name if single_name == "#{name_first_word} Central"
    # raise 'boom'

    return single_name.gsub(name_first_word, name_first_word + ",") if SUBDIVIDED_CITIES.include?(name_first_word)

    single_name
  end

  def single_name_mapped_to_normalised_name(single_name)
    name_first_word = single_name.strip.split(" ").first

    compass_part = COMPASS_PARTS.detect{ |cp| single_name =~ / #{cp}$/ || single_name =~ /^#{cp} / }
    unless compass_part.nil?
      # puts "COMPASS PART #{compass_part} detected"
      return single_name.gsub(compass_part, "").strip + " #{compass_part}"
    end

    return single_name if single_name == name_first_word
    # return single_name if single_name == "#{name_first_word} Central"

    single_name
  end
end
