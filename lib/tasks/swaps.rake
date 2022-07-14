
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

      def sort_hash_by_value(d)
        d.to_a.sort{ |x,y| x.last <=> y.last }.to_h
      end

      threshold_text = "Marginal Threshold: #{OnsConstituency::MARGINAL_THRESHOLD}"

      swaps = Swap.joins(:choosing_user => :constituency, :chosen_user => :constituency).eager_load(:chosen_user, :choosing_user).where(confirmed: true).all

      voters = Hash.new
      voter_gains = Hash.new
      diff_gains = Hash.new
      pairs = Hash.new

      diff_3_gains = Hash.new

      swaps.each do |swap|
        u1 = swap.choosing_user
        u2 = swap.chosen_user

        c1 = Poll::Cache.get_constituency(u1.constituency_ons_id)
        c2 = Poll::Cache.get_constituency(u2.constituency_ons_id)


        u1_type = c1.combined_type(u1)
        u2_type = c2.combined_type(u2)

        u1_gain_type = c2.combined_type(u1)
        u2_gain_type = c1.combined_type(u2)

        u1_gain = c2.user_party_vote_share(u1) - c1.user_party_vote_share(u1)
        u2_gain = c1.user_party_vote_share(u2) - c2.user_party_vote_share(u2)

        u1_gain_words = u1_gain > 0 ? "positive" : (c1.user_is_potentially_a_defeater?(u1) ? "defeat" : "none")
        u2_gain_words = u2_gain > 0 ? "positive" : (c2.user_is_potentially_a_defeater?(u2) ? "defeat" : "none")

        # # if (u1_type == 'fighting-marginal' && (c1.user_is_primarily_defeater?(u1))
        #   puts "\n\nu1_type", u1_type
        #   c1.dump_before_raise(u1)
        #   raise "first fighting marginal defeater"
        # # end

        if (u1_gain_type == 'losing-safe' && u2_gain_type == 'losing-safe')
          # puts "\nBEFORE SWAP"
          # c1.dump_before_raise(u1)
          # c2.dump_before_raise(u2)
          # puts "\nAFTER SWAP"
          # c1.dump_before_raise(u2)
          # c2.dump_before_raise(u1)
          # raise "first double loosing safe"

          # u1_type = u1_type + c1.marginal_degree
          # u2_type = u2_type + c2.marginal_degree

          # u1_gain_type = u1_gain_type + c2.marginal_degree
          # u2_gain_type = u2_gain_type + c1.marginal_degree
        end

        pairs[swap.id] = [u1_type, u2_type].sort.join("-SWAPPED_WITH-")

        voters[u1.id] = u1_type + (c1.user_is_primarily_defeater?(u1) ? "-defeater" : "")
        voters[u2.id] = u2_type + (c2.user_is_primarily_defeater?(u2) ? "-defeater" : "")

        voter_gains[u1.id] = u1_type + "-GAINS-" + u1_gain_words
        voter_gains[u2.id] = u2_type + "-GAINS-" + u2_gain_words

        diff_gains[u1.id] = "MY-GAIN-" + u1_gain_words + "-SWAPPER-GAIN-" + u2_gain_words
        diff_gains[u2.id] = "MY-GAIN-" + u2_gain_words + "-SWAPPER-GAIN-" + u1_gain_words

        diff_3_gains[u1.id] = u1_type + "-MY-GAIN-" + u1_gain_words + "-SWAPPER-GAIN-" + u2_gain_words
        diff_3_gains[u2.id] = u2_type + "-MY-GAIN-" + u2_gain_words + "-SWAPPER-GAIN-" + u1_gain_words
      end

      puts "\n\nVOTERS -", threshold_text
      # puts voters.map{ |(id,type)| type }.tally
      pp sort_hash_by_value(voters.map{ |(id,type)| type }.tally)

      puts "\n\nVOTER PAIRS -", threshold_text
      pp sort_hash_by_value(pairs.map{ |(id,type)| type }.tally)

      puts "\n\nIMMEDIATE VOTER GAINS -", threshold_text
      # puts voter_gains.map{ |(id,type)| type }.tally
      pp sort_hash_by_value(voter_gains.map{ |(id,type)| type }.tally)

      puts "\n\nDIFFERENTIAL GAINS -", threshold_text
      # puts diff_gains.map{ |(id,type)| type }.tally
      pp sort_hash_by_value( diff_gains.map{ |(id,type)| type }.tally )

      puts "\n\n3-WAY DIFFERENTIAL GAINS -", threshold_text
      # puts diff_3_gains.map{ |(id,type)| type }.tally
      pp sort_hash_by_value(diff_3_gains.map{ |(id,type)| type }.tally)

      swapper_ids = voters.map{ |(id, type)| id}

      not_swaps = User.joins(:constituency, :preferred_party).where("users.id not in (?)", swapper_ids)

      not_swap_result = Hash.new

      not_swaps.each do |user|
        c1 = Poll::Cache.get_constituency(user.constituency_ons_id)
        unless c1.nil? || user.preferred_party_id.nil?
          type = c1.combined_type(user) + (c1.user_is_primarily_defeater?(user) ? "-defeater" : "")
          not_swap_result[user.id] = type
        end
      end

      puts "\n\nUSERS WHO DIDN'T SWAP -", threshold_text
      # puts not_swap_result.map{ |(id,type)| type }.tally
      pp sort_hash_by_value(not_swap_result.map{ |(id,type)| type }.tally)


    end
  end
end
