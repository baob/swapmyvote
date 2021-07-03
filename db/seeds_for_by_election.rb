# This file should contain all the record creation needed to seed the database with its default values.
# The data can then be loaded with the rake db:seed (or created alongside the db with db:setup).
#
# Examples:
#
#   cities = City.create([{ name: 'Chicago' }, { name: 'Copenhagen' }])
#   Mayor.create(name: 'Emanuel', city: cities.first)

require_relative "fixtures/be2022_yaml"
require_relative "fixtures/be2022/party"
require_relative "fixtures/be2022/candidate"
require_relative "fixtures/electoral_commission_parties"

# ---------------------------------------------------------------------------------

ec_data =  Db::Fixtures::ElectoralCommissionParties.new
ec_parties = ec_data.unique_entities_joint_merged.values

ec_parties_by_name = ec_parties.each_with_object({}) do |party, index|
  names = party[:regulated_entity_names] + party[:descriptions]
  names << party[:name]

  names.each do |name|
    index[name] = party
    index[name][:shortest_name] = names.sort { |a, b| a.length <=> b.length }.first
  end
end

puts "\nParties"

Db::Fixtures::Be2022::Party.all.each do |party|
  party_name = party[:name].strip
  unless ec_parties_by_name[party_name]
    puts "party #{party} from BE2022 yaml file not found in Electoral Commission data"
    puts "try one of these \n"
    puts ec_parties_by_name.keys.sort.join("|")
    exit(1)
  end
  ::Party.find_or_create_by(name: party[:name], color: party[:colour])
  puts "Party #{party[:name]} created"
end

# ---------------------------------------------------------------------------------

puts "\nConstituencies"

Db::Fixtures::Be2022Yaml.data[:constituencies].each do |constituency|
  cons = OnsConstituency.find_or_initialize_by ons_id: constituency[:ons_id]
  puts "#{cons.ons_id} #{cons.name}"
  cons.update!(constituency.slice(:name, :ons_id))
end

puts "#{OnsConstituency.count} Constituencies loaded\n\n"

# ---------------------------------------------------------------------------------

puts "\n\nPolls Data\n\n"

Db::Fixtures::Be2022::Candidate.all.each do |candidate|
  vote_count = candidate[:votes_percent] ? (candidate[:votes_percent] * 100).to_i : nil
  ons_id = candidate[:constituency_ons_id]
  party_name = candidate[:party_name]

  party = ::Party.find_by(name: party_name)

  unless party
    raise "No matching party for #{party_name}"
  end

  poll = Poll.find_or_initialize_by constituency_ons_id: ons_id, party_id: party.id

  if vote_count
    poll.votes = vote_count
    poll.save!
  end
  print "."
end
puts "\n\n"

# ---------------------------------------------------------------------------------

puts "\n\nCalculate Marginal Score\n\n"

Poll.calculate_marginal_score(progress: true)

puts "\n\n"

# ---------------------------------------------------------------------------------

puts "\n\nVerifying canonical names include in api\n\n"

party_canonical_names = Party.canonical_names

Party.all.each do |party|
  canonical_name = Party.canonical_name_for(party.name)
  unless party_canonical_names.include?(canonical_name)
    puts "ERROR: canonical name (#{canonical_name}) for party #{party.name} not included in Party.REFERENCE_DATA"
  end
  print "."
end

puts "\n\n"
