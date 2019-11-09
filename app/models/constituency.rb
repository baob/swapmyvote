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

  def name_mapped_to_ons_name
    name_split_by_and = name.match(/^(.*) and (.*)$/)
    return single_name_mapped_to_ons_name(name) if name_split_by_and.nil?
    name_split_by_and.captures.map{ |n| single_name_mapped_to_ons_name(n) }.join(" and ")
  end

  private

  def single_name_mapped_to_ons_name(name)
    name_first_word = name.strip.split(" ").first
    return name if name == name_first_word
    return name if name == "#{name_first_word} Central"

    return name.gsub(name_first_word, name_first_word + ",") if SUBDIVIDED_CITIES.include?(name_first_word)

    name
  end
end
