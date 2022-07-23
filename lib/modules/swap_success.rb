module SwapSuccess
  SMALL_GROUP_THRESHOLD = 8

  class << self
    def order_keys_for_uniqueness(k1, k2)
      k1.hash > k2.hash ? [k1, k2] : [k2, k1]
    end

    # success_count is a hash, represent counts of confirmed and unconfirned swaps for a given group of voters.

    def score_conf_or_not_value(success_count, expected_good_bad_ratio)
      biased_not_conf_count = Float(expected_good_bad_ratio * (success_count[false] || 0))
      conf_count = success_count[true] || 0
      return conf_count * 2 / (conf_count + biased_not_conf_count)
    end

    def keep_success_count(o, success_counts)
      two_counts = [success_counts[o][false] || 0 , success_counts[o][true] || 0]

      two_counts.sum > SMALL_GROUP_THRESHOLD
    end

    def explanation_lines
      [
        "SCORING PRINCIPLE: scores (after =>) represent relative success at turning proposed swaps into confirmed swaps.",
        "2.0 means 100% of them, 0.0 means none of them.",
        "Threshold between marginal and safe seat is a difference between the first two party votes of #{OnsConstituency::MARGINAL_THRESHOLD/100.0}%",
        "",
        "Values before the => represent the two voters participating in the swap, and what they gain for their preferred party.",
        "E.g. fighting-2-winning indicates that voter's preferred party instead of getting a vote in marginal where they are fighting,",
        "instead gets a vote in a constituency where they are winning",
      ]
    end

    def swap_success_lookup
      choosing = User.left_joins(:outgoing_swap)
        .where("swaps.id IS NOT ?", nil)
        .where("users.constituency_ons_id LIKE '_%'")
        .eager_load(outgoing_swap: :chosen_user)

      total_confirmed = choosing.where(swaps: { confirmed: true }).count
      total_unconfirmed = choosing.where(swaps: { confirmed: false }).count
      expected_good_bad_ratio = total_confirmed / Float(total_unconfirmed)

      threeway = choosing.map do |chooser|
        chosen = chooser.outgoing_swap.chosen_user
        [chooser.bucket_with(chosen.constituency_ons_id), chosen.bucket_with(chooser.constituency_ons_id), chooser.outgoing_swap.confirmed]
      end.tally

      result = Hash.new{ |o, k| o[k] = Hash.new { |o, k| o[k] = 0 } }

      # now get the true/false values into a single hash for each group
      success_counts = threeway.each_with_object(result) do |(k, tally), r|
        chooser_bucket = k[0]
        chosen_bucket = k[1]
        success_or_not = k[2]

        # for figuring out if the swap is a success or not,
        # the order of the keys (swap proposer/swap receiver) doesn't matter,
        # both counts go into the same group
        new_key = order_keys_for_uniqueness(chooser_bucket, chosen_bucket)

        r[new_key][success_or_not] += tally
      end

      # now for each group, turn the pair of counts into a score, and return a hash of all of those
      success_counts.map do |(pair, success_count)|
        [pair, score_conf_or_not_value(success_count, expected_good_bad_ratio)]
      end.to_h
    end
  end
end
