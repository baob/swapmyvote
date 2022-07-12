
namespace :swaps do
  desc "Print a CSV of confirmed swaps"
  task csv: :environment do
    ActiveRecord::Base.logger = nil
    print "Name,Email,Constituency,Will Vote For,Swap ID\n"
    Swap.where(confirmed: true).each {|s|
      print "#{s.choosing_user.try(:name)},#{s.choosing_user.try(:email)},\"#{s.choosing_user.try(:constituency).try(:name)}\",#{s.choosing_user.try(:willing_party).try(:name)},#{s.created_at},#{s.id}\n"
      print "#{s.chosen_user.try(:name)},#{s.chosen_user.try(:email)},\"#{s.chosen_user.try(:constituency).try(:name)}\",#{s.chosen_user.try(:willing_party).try(:name)},#{s.created_at},#{s.id}\n"
    }
  end

  desc "Show swaps which are older than the validity period " \
       "in ENV['SWAP_EXPIRY_HOURS']"
  task show_old: :environment do
    ActiveRecord::Base.logger = Logger.new STDOUT
    Swap.show_old
  end

  desc "Cancel swaps which are older than the validity period " \
       "in ENV['SWAP_EXPIRY_HOURS']"
  task cancel_old: :environment do
    ActiveRecord::Base.logger = Logger.new STDOUT
    Swap.cancel_old
  end

  namespace :analysis do
    desc "breakdown the swaps"
    task breakdown: :environment do
      swaps = Swap.where(confirmed: true).all

      voters = Hash.new
      voter_gains = Hash.new
      diff_gains = Hash.new

      diff_3_gains = Hash.new

      swaps.each do |swap|
        u1 = swap.choosing_user
        u2 = swap.chosen_user

        u1_type = u1.constituency.combined_type(u1)
        u2_type = u2.constituency.combined_type(u2)

        u1_gain_type = u2.constituency.combined_type(u1)
        u2_gain_type = u1.constituency.combined_type(u2)

        voters[u1.id] = u1_type
        voters[u2.id] = u2_type

        voter_gains[u1.id] = u1_type + "-GAINS-" + u1_gain_type
        voter_gains[u2.id] = u2_type + "-GAINS-" + u2_gain_type

        diff_gains[u1.id] = "MY-GAIN-" + u1_gain_type + "-SWAPPER-GAIN-" + u2_gain_type
        diff_gains[u2.id] = "MY-GAIN-" + u2_gain_type + "-SWAPPER-GAIN-" + u1_gain_type

        diff_3_gains[u1.id] = u1_type + "-MY-GAIN-" + u1_gain_type + "-SWAPPER-GAIN-" + u2_gain_type
        diff_3_gains[u2.id] = u2_type + "-MY-GAIN-" + u2_gain_type + "-SWAPPER-GAIN-" + u1_gain_type
      end

      puts "\n\nVOTERS"
      puts voters.map{ |(id,type)| type }.tally

      puts "\n\nIMMEDIATE VOTER GAINS"
      puts voter_gains.map{ |(id,type)| type }.tally

      puts "\n\nDIFFERENTIAL GAINS"
      puts diff_gains.map{ |(id,type)| type }.tally

      puts "\n\n3-WAY DIFFERENTIAL GAINS"
      puts diff_3_gains.map{ |(id,type)| type }.tally

      swapper_ids = voters.map{ |(id, type)| id}

      not_swaps = User.where("id not in (?)", swapper_ids)

      not_swap_result = Hash.new

      not_swaps.each do |user|
        unless user.constituency.nil? || user.preferred_party.nil?
          type = user.constituency.combined_type(user)
          not_swap_result[user.id] = type
        end
      end

      puts "\n\nUSERS WHO DIDN'T SWAP"
      puts not_swap_result.map{ |(id,type)| type }.tally


    end
  end
end
