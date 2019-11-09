namespace :constituencies do

  desc "match the two constituency tables"
  task :match => :environment do

    constituencies = Constituency.all.reduce({}){ |hash, c| hash[c.normalised_name] = c ; hash }
    puts constituencies.take(3)

    ons_constituencies = OnsConstituency.all.reduce({}){ |hash, c| hash[c.normalised_name] = c ; hash }
    puts ons_constituencies.take(3)
  #  ons_constituencies = OnsConstituency.pluck(:ons_id, :name).reduce({}){ |hash, c|  hash[c[1]] = { ons_id: c[0], name: c[1] } ; hash }

    misses = 0
    constituencies.each do |name, constituency|
      # name = constituency.name.strip

      # name = constituency.name_mapped_to_ons_name

      if ons_constituencies.key?(name)
        # crosslink the hashes
        # constituency[:ons_id] = ons_constituencies[name][:ons_id]
        # ons_constituencies[name][:matched] = constituency
      else
        misses += 1
        name_first = constituency.normalised_name.split('|').first.split(' ').first
        puts "No match for original #{constituency.name} (#{constituency.normalised_name} == #{name}) "

        ons_keys = ons_constituencies.keys.select{ |name|  name.index(name_first)}

        ons_results = ons_keys.map do |ons_key|
          { ons_key => ons_constituencies[ons_key].name }
        end

        puts "Close matches on #{name_first} from ONS: #{ons_results}"
      end
    end

    puts "Total #{misses} misses"
  end
end