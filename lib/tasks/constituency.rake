namespace :constituencies do

  desc "match the two constituency tables"
  task :match => :environment do

    constituencies = Constituency.all.reduce({}){ |hash, c| hash[c.name] = c ; hash }
    # puts constituencies.take(3)

    ons_constituencies = OnsConstituency.pluck(:ons_id, :name).reduce({}){ |hash, c|  hash[c[1]] = { ons_id: c[0], name: c[1] } ; hash }
    # puts ons_constituencies.take(3)

    misses = 0
    constituencies.each do |name, constituency|
      # name = constituency.name.strip

      name = constituency.name_mapped_to_ons_name

      if ons_constituencies.key?(name)
        # crosslink the hashes
        # constituency[:ons_id] = ons_constituencies[name][:ons_id]
        ons_constituencies[name][:matched] = constituency
      else
        misses += 1
        name_first = name.split(' ').first.split(',').first
        puts "No match for original #{constituency.name}"

        ons_results = ons_constituencies.keys.select{ |name|  name.index(name_first)}

        puts "Close matches ONS: #{ons_results}"
      end
    end

    puts "Total #{misses} misses"
  end
end