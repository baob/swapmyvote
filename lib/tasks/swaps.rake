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

    task analysis_setup: :environment do
      require_relative '../modules/swap_conversions'
    end


    desc "breakdown the swaps - EXPERIMENTAL"
    task breakdown: :analysis_setup do

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

        u1_type = c1.voter_type(u1)
        u2_type = c2.voter_type(u2)

        u1_strategy = c1.voter_strategy(u1)
        u2_strategy = c2.voter_strategy(u2)

        voters[u1.id] = u1_type + (u1_strategy ? "-#{u1_strategy}" : "")
        voters[u2.id] = u2_type + (u2_strategy ? "-#{u2_strategy}" : "")

        no_polls = c1.polls_count == 0 || c2.polls_count == 0

        unless no_polls

          u1_gain = SwapConversions::UserUtils.new(u1).effort_reduction(u2.constituency_ons_id)
          u2_gain = SwapConversions::UserUtils.new(u2).effort_reduction(u1.constituency_ons_id)

          u1_gain_list = u1_gain > 0 ? ["preferred"] :  []
          u2_gain_list = u2_gain > 0 ? ["preferred"] :  []
          u1_gain_list.push("willing") if u2_gain > 0
          u2_gain_list.push("willing") if u1_gain > 0

          u1_may_be_a_defeater = c1.voter_may_have_defeat_strategy?(u1) ||
                                 c2.voter_may_have_defeat_strategy?(u1)
          u2_may_be_a_defeater = c2.voter_may_have_defeat_strategy?(u2) ||
                                 c1.voter_may_have_defeat_strategy?(u2)

          u1_gain_list = u1_may_be_a_defeater ? ["defeat"] : ["none"] if u1_gain_list.size == 0
          u2_gain_list = u2_may_be_a_defeater ? ["defeat"] : ["none"] if u2_gain_list.size == 0

          u1_gain_words = u1_gain_list.join("-")
          u2_gain_words = u2_gain_list.join("-")

          pairs[swap.id] = [u1_type, u2_type].sort.join("-SWAPPED_WITH-")


          voter_gains[u1.id] = u1_type + "-GAINS-" + u1_gain_words
          voter_gains[u2.id] = u2_type + "-GAINS-" + u2_gain_words

          diff_gains[swap.id] = [u1_gain_words, u2_gain_words].sort.join("-OTHER-GAIN-")

          diff_3_gains[u1.id] = u1_type + "-MY-GAIN-" + u1_gain_words + "-SWAPPER-GAIN-" + u2_gain_words
          diff_3_gains[u2.id] = u2_type + "-MY-GAIN-" + u2_gain_words + "-SWAPPER-GAIN-" + u1_gain_words
        end
      end

      puts "\n\nVOTERS (SWAPPERS) CLASSIFIED -", threshold_text
      pp sort_hash_by_value(voters.map{ |(id,type)| type }.tally)

      swapper_ids = voters.map{ |(id, type)| id}

      not_swaps = User.joins(:constituency, :preferred_party).where("users.id not in (?)", swapper_ids)

      not_swap_result = Hash.new

      not_swaps.each do |user|
        c1 = Poll::Cache.get_constituency(user.constituency_ons_id)
        unless c1.nil? || user.preferred_party_id.nil?
          strategy = c1.voter_strategy(user)
          type = c1.voter_type(user) + ( strategy ? "-#{strategy}" : "")
          not_swap_result[user.id] = type
        end
      end

      puts "\n\nVOTERS (NOT SWAPPED) CLASSIFIED -", threshold_text
      pp sort_hash_by_value(not_swap_result.map{ |(id,type)| type }.tally)


      puts "\n\nVOTER PAIRS -", threshold_text
      pp sort_hash_by_value(pairs.map{ |(id,type)| type }.tally)

      puts "\n\nIMMEDIATE VOTER GAINS -", threshold_text
      pp sort_hash_by_value(voter_gains.map{ |(id,type)| type }.tally)

      puts "\n\nDIFFERENTIAL GAINS -", threshold_text
      pp sort_hash_by_value( diff_gains.map{ |(id,type)| type }.tally )

      puts "\n\n3-WAY DIFFERENTIAL GAINS -", threshold_text
      pp sort_hash_by_value(diff_3_gains.map{ |(id,type)| type }.tally)



    end

    desc "classify swaps into buckets and show a conversion metric"
    task conversion_metrics: :analysis_setup do

      def sort_hash_by_value(d)
        d.to_a.sort{ |x,y| x.last <=> y.last }.to_h
      end

      # ---------------- SWAPS SCORING BASED ON CONFIRMED/UNCONFIRMED ---------------------

      # explain yourself
      puts ""
      puts SwapConversions.explanation_lines.join("\n")

      lookup = SwapConversions.swap_conversion_lookup

      puts "\n\nsparse map (small groups under 30 eliminated)"
      pp sort_hash_by_value(lookup).select{ |x, y|  y[1] >= 30 }.map{ |x,y| [x, [y[0].round(2), y[1]]]}

      all_scores = lookup.map{ |k,v| v }
      average = all_scores.map{ |s| s[0]}.sum/Float(all_scores.size)

      puts "\naverage = ", average
    end

    desc "classify swaps into buckets - figure out if the old potential swaps algorithm is good"
    task potential_swaps: :analysis_setup do

      # TODO: explain yourself

      lookup = SwapConversions.swap_conversion_lookup

      # -------------------------------- POTENTIAL SWAPS ---------------------------------

      all_p_swaps = PotentialSwap
        .eager_load(:source_user => :constituency, :target_user => :constituency)
        .where("ons_constituencies.ons_id IS NOT ?", nil)
        .where("constituencies_users.ons_id IS NOT ?", nil) # .all.map{ |x| :fred}

      p_swap_scores = all_p_swaps.map do |ps|

        c2 = Poll::Cache.get_constituency(ps.target_user.constituency_ons_id)
        c1 = Poll::Cache.get_constituency(ps.source_user.constituency_ons_id)

        no_polls = c1.polls_count == 0 || c2.polls_count == 0

        if no_polls
          score = 0
        else
          k1 = SwapConversions.user_bucket_with(ps.source_user, ps.target_user.constituency_ons_id)
          k2 = SwapConversions.user_bucket_with(ps.target_user, ps.source_user.constituency_ons_id)

          score = lookup[ SwapConversions.order_keys_for_uniqueness(k1, k2) ] || 0
        end
      end.compact.map{ |x, y| x.round(1)} # discard the group count so that same score values get merged in the tally

      puts "\n\nFor all potential swaps, show percentage splits for each possible score.  score => percentage of potential swaps with that score"
      pp p_swap_scores.tally.sort.map{ |k,v| [k, (v*100.0/p_swap_scores.size).round(1)]}.to_h ; nil
      puts "percentage of potential swaps evaluated #{(p_swap_scores.size*100.0/all_p_swaps.size).round(1)}"
    end

    desc "classify swaps into buckets - figure out the conversion score over every potential swap"
    task all_possible_swap_types: :analysis_setup do

      # TODO: explain yourself

      lookup = SwapConversions.swap_conversion_lookup

      # ---------------------- ALL POSSIBLE VARIATIONS OF SWAPS --------------------------

      users = User
        .where("ons_constituencies.ons_id IS NOT ?", nil)
        .where("users.preferred_party_id IS NOT ?", nil)
        .where("users.willing_party_id IS NOT ?", nil)
        .eager_load([ :constituency ]) # .limit(2000)

      user_types = Hash.new { |o,k|  o[k]= 0}
      swap_types = Hash.new { |o,k|  o[k]= 0}

      users.each do |user|
        key = { preferred_party_id: user.preferred_party_id, willing_party_id: user.willing_party_id, constituency_ons_id: user.constituency_ons_id }
        user_types[key] += 1
      end

      puts "\nuser types #{user_types.count}"
      puts "users      #{users.count}"

      user_types.each do |(type, count)|
        user = User.new(type)
        comps = user.every_complementary_voter.pluck(:constituency_ons_id)
        comps.each do |comp|
          key = type
          key[:other_ons_id] = comp
          swap_types[key] += count
        end
      end

      puts "\nuser types #{user_types.count}"
      puts "swap types #{swap_types.count}"
      puts "users      #{users.count}"

      puts "\nlargest swap type group #{swap_types.values.max}"
      puts "smallest swap type group #{swap_types.values.min}"
      puts "average swap type group #{swap_types.values.sum / Float(swap_types.values.count)}"

      puts "\nCODE INCOMPLETE - ADD SUCCESS METRICS"
    end

  end
end
