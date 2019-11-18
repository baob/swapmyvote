namespace :constituencies do

  desc "match the two constituency tables"
  task :match => :environment do

    constituencies = Constituency.all.reduce({}){ |hash, c| hash[c.normalised_name] = { cons: c} ; hash }
    # puts constituencies.take(3)

    ons_constituencies = OnsConstituency.all.reduce({}){ |hash, c| hash[c.normalised_name] = { cons: c} ; hash }
    # puts ons_constituencies.take(3)
  #  ons_constituencies = OnsConstituency.pluck(:ons_id, :name).reduce({}){ |hash, c|  hash[c[1]] = { ons_id: c[0], name: c[1] } ; hash }

    misses = 0
    constituencies.each do |name, cons_result|
      constituency = cons_result[:cons]

      # name = constituency.name.strip

      # name = constituency.name_mapped_to_ons_name

      if ons_constituencies.key?(name)
        # crosslink the hashes
        ons_id = ons_constituencies[name][:cons][:ons_id]
        cons_result[:ons_id] = ons_id

        # puts "cons_result: #{cons_result.inspect}"
        # puts "constituency: #{constituency.inspect}"
        # puts "constituencies[name]: #{constituencies[name].inspect}"
        # raise "kaboom"
        ons_constituencies[name][:matched] = constituency
      else
        misses += 1
        name_first = constituency.normalised_name.split('|').first.split(' ').first
        puts "No match for original #{constituency.name} (Normalised name: #{constituency.normalised_name}) "

        ons_keys = ons_constituencies.keys.select{ |name|  name.index(name_first)}

        ons_results = ons_keys.map do |ons_key|
          { ons_key => ons_constituencies[ons_key][:cons].name }
        end

        puts "Close matches on #{name_first} from ONS: #{ons_results}"
      end
    end

    puts "Total #{misses} misses\n\n\n"

    puts "original constituency names with ons ids where known:\n\n"

    puts 'ons_id,original_constituency_name'
    constituencies.each do |name, cons_result|
      constituency = cons_result[:cons]
      ons_id = cons_result[:ons_id] || ""
      puts "#{ons_id.inspect},#{constituency.name.inspect}"
    end


    puts "\n\n\n"

    puts "ONS constituencies left unmatched:\n\n"

    puts 'ons_id,ons_constituency_name'
    ons_constituencies.
      select { |name, cons_result| cons_result[:matched].nil? }.
      each do |name, cons_result|
        constituency = cons_result[:cons]
        puts "#{constituency.ons_id.inspect},#{constituency.name.inspect}"
      end



  end
end