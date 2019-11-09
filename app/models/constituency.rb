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
    "South East",
    "East",
    "North"
  ]

  def name_mapped_to_ons_name
    name_split_by_and = name.match(/^(.*) and (.*)$/)
    return single_name_mapped_to_ons_name(name) if name_split_by_and.nil?
    name_split_by_and.captures.map{ |n| single_name_mapped_to_ons_name(n) }.join(" and ")
  end

  private

  def single_name_mapped_to_ons_name(single_name)
    name_first_word = single_name.strip.split(" ").first
    compass_part = COMPASS_PARTS.detect{ |cp| "#{name_first_word} #{cp}" == single_name }
    return single_name unless compass_part.nil?
    return single_name if single_name == name_first_word
    return single_name if single_name == "#{name_first_word} Central"

    return single_name.gsub(name_first_word, name_first_word + ",") if SUBDIVIDED_CITIES.include?(name_first_word)

    single_name
  end
end
