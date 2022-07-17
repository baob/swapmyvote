
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

    desc "expermient with metrics - classify swaps into buckets"
    task metrics: :environment do

      choosing  = User.left_joins(:outgoing_swap).where("swaps.id IS NOT ?", nil).where("users.constituency_ons_id LIKE '_%'").eager_load(outgoing_swap: :chosen_user)
      expected_good_bad_ratio = choosing.where("swaps.confirmed = ?", true).count/Float(choosing.where("swaps.confirmed = ?", false).count)

      threeway = choosing.map{ |c| o = c.outgoing_swap.chosen_user; [(c.effort_reduction_from_swap_with(o)/1000.0).floor, (o.effort_reduction_from_swap_with(c)/1000.0).floor, c.outgoing_swap.confirmed] }.tally

      result = Hash.new{ |o,k| o[k] = Hash.new { |o,k| o[k] = 0 } }
      twoway = threeway.each_with_object(result) { |(k,v), r| new_k = [k[0], k[1]].sort ;  new_sub_k = k[2] ; r[new_k][new_sub_k] = v  }

      lookup = twoway.select{ |o| twoway[o].size == 2 && twoway[o][false] > 0}.map{  |(pair, value)| [pair, value[true]/Float(expected_good_bad_ratio * value[false])] }.sort.to_h

      puts "\n\nsparse map"
      pp lookup ; nil

      filled_map = Hash.new
      # diagonal_map = Hash.new { |o,k|  o[k] = []}
      (-2..3).map do |x|
        (-2..3).map do |y|
          key = [x,y].sort
          filled_map[[x, y]] = lookup[key]
          # diagonal_map[x+y].push(lookup[key])
        end
      end

      puts "\n\nfilled_map"
      pp filled_map ; nil
      # pp "\n\ndiagonal_map", diagonal_map ; nil

    end

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

        u1_gain = u1.vote_share_gain_from_swap_with(u2)
        u2_gain = u2.vote_share_gain_from_swap_with(u1)

        u1_gain_list = u1_gain > 0 ? ["preferred"] :  []
        u2_gain_list = u2_gain > 0 ? ["preferred"] :  []
        u1_gain_list.push("willing") if u2_gain > 0
        u2_gain_list.push("willing") if u1_gain > 0

        u1_may_be_a_defeater = c1.voter_may_have_defeat_strategy?(u1.willing_party_id) ||
                               c2.voter_may_have_defeat_strategy?(u1.preferred_party_id)
        u2_may_be_a_defeater = c2.voter_may_have_defeat_strategy?(u2.willing_party_id) ||
                               c1.voter_may_have_defeat_strategy?(u2.preferred_party_id)

        u1_gain_list = u1_may_be_a_defeater ? ["defeat"] : ["none"] if u1_gain_list.size == 0
        u2_gain_list = u2_may_be_a_defeater ? ["defeat"] : ["none"] if u2_gain_list.size == 0

        u1_gain_words = u1_gain_list.join("-")
        u2_gain_words = u2_gain_list.join("-")

        pairs[swap.id] = [u1_type, u2_type].sort.join("-SWAPPED_WITH-")

        voters[u1.id] = u1_type + (c1.user_is_primarily_defeater?(u1) ? "-defeater" : "")
        voters[u2.id] = u2_type + (c2.user_is_primarily_defeater?(u2) ? "-defeater" : "")

        voter_gains[u1.id] = u1_type + "-GAINS-" + u1_gain_words
        voter_gains[u2.id] = u2_type + "-GAINS-" + u2_gain_words

        diff_gains[swap.id] = [u1_gain_words, u2_gain_words].sort.join("-OTHER-GAIN-")

        diff_3_gains[u1.id] = u1_type + "-MY-GAIN-" + u1_gain_words + "-SWAPPER-GAIN-" + u2_gain_words
        diff_3_gains[u2.id] = u2_type + "-MY-GAIN-" + u2_gain_words + "-SWAPPER-GAIN-" + u1_gain_words
      end

      puts "\n\nVOTERS -", threshold_text
      pp sort_hash_by_value(voters.map{ |(id,type)| type }.tally)

      puts "\n\nVOTER PAIRS -", threshold_text
      pp sort_hash_by_value(pairs.map{ |(id,type)| type }.tally)

      puts "\n\nIMMEDIATE VOTER GAINS -", threshold_text
      pp sort_hash_by_value(voter_gains.map{ |(id,type)| type }.tally)

      puts "\n\nDIFFERENTIAL GAINS -", threshold_text
      pp sort_hash_by_value( diff_gains.map{ |(id,type)| type }.tally )

      puts "\n\n3-WAY DIFFERENTIAL GAINS -", threshold_text
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
      pp sort_hash_by_value(not_swap_result.map{ |(id,type)| type }.tally)

    end
  end
end
