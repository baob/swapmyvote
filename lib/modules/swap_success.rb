module SwapSuccess


  class << self

    def order_keys_for_uniqueness(k1, k2)
      k1.hash > k2.hash ? [k1, k2] : [k2, k1]
    end

    def score_conf_or_not_value(value, ratio)
      biased_not_conf_count = Float(ratio * (value[false] || 0))
      conf_count = value[true] || 0
      return conf_count * 2 / (conf_count + biased_not_conf_count)
    end

    def swap_success_lookup
      choosing  = User.left_joins(:outgoing_swap).where("swaps.id IS NOT ?", nil).where("users.constituency_ons_id LIKE '_%'").eager_load(outgoing_swap: :chosen_user)
      expected_good_bad_ratio = choosing.where("swaps.confirmed = ?", true).count/Float(choosing.where("swaps.confirmed = ?", false).count)

      # puts "\nSCORING PRINCIPLE: scores (after =>) represent relative success at turning proposed swaps into confirmed swaps."
      # puts "2.0 means 100% of them, 0.0 means none of them."
      # puts "Threshold between marginal and safe seat is a difference between the first two party votes of #{OnsConstituency::MARGINAL_THRESHOLD/100.0}%"

      # puts "\nValues before the => represent the two voters participating in the swap, and what they gain for their preferred party."
      # puts "E.g. fighting-2-winning indicates that voter's preferred party instead of getting a vote in marginal where they are fighting,"
      # puts "instead gets a vote in a constituency where they are winning"

      threeway = choosing.map{ |c| o = c.outgoing_swap.chosen_user; [c.bucket_with(o.constituency_ons_id), o.bucket_with(c.constituency_ons_id), c.outgoing_swap.confirmed] }.tally

      result = Hash.new{ |o,k| o[k] = Hash.new { |o,k| o[k] = 0 } }
      twoway = threeway.each_with_object(result) { |(k,v), r|  new_k = order_keys_for_uniqueness(k[0], k[1]) ;  new_sub_k = k[2] ; r[new_k][new_sub_k] = v  }


      lookup = twoway.select{ |o| two_counts = [twoway[o][false] || 0 , twoway[o][true] || 0]; two_counts.sum > 8 }.map{ |(pair, value)| [pair, score_conf_or_not_value(value, expected_good_bad_ratio)] }.to_h
    end
  end


end
