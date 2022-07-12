
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
      voter_gains =Hash.new

      swaps.each do |swap|
        u1 = swap.choosing_user
        u2 = swap.chosen_user

        u1_type = u1.constituency.combined_type(u1)
        u2_type = u2.constituency.combined_type(u2)

        u1_gain_type = u2.constituency.combined_type(u1)
        u2_gain_type = u1.constituency.combined_type(u2)

        voters[u1_type] ||= 0
        voters[u1_type] += 1

        voters[u2_type] ||= 0
        voters[u2_type] += 1
      end

      puts "\n\nVOTERS"
      puts voters

    end
  end
end
