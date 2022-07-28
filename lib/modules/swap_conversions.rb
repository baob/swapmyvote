module SwapConversions
  SMALL_GROUP_THRESHOLD = 8

  class UserUtils
    attr_reader :user
    def initialize(user)
      @user = user
    end

    def dump_and_raise(poll)
      puts "votes nil problem"
      puts "poll", poll.attributes
      puts "user", user.attributes
      constituency = OnsConstituency.find_by(ons_id: poll.constituency_ons_id)
      puts "constituency name", user.constituency.attributes
      puts "constituency polls", user.constituency.polls.map(&:attributes)
      party = Party.find(user.preferred_party_id)
      puts "party", party.attributes
      raise "votes nil problem"
    end

    def two_polls_from_cache(ons_id)
      poll1 = Poll::Cache.get(constituency_ons_id: user.constituency_ons_id, party_id: user.preferred_party_id)
      poll2 = Poll::Cache.get(constituency_ons_id: ons_id, party_id: user.preferred_party_id)

      dump_and_raise(poll1) if poll1&.safe_votes.nil?
      dump_and_raise(poll2) if poll2&.safe_votes.nil?

      # NOTE: poll from MY constituency is first
      [poll1, poll2]
    end

    def effort_reduction(ons_id)
      polls = two_polls_from_cache(ons_id)

      effort_reduction = polls.first.effort_to_win - polls.last.effort_to_win
      (effort_reduction / 1000.0).ceil
    end

    def marginal_reduction(ons_id)
      polls = two_polls_from_cache(ons_id)

      marginal_reduction = (polls.first.effort_to_win.abs - polls.last.effort_to_win.abs)
      (marginal_reduction / 1000.0).round
    end

    def category_with(ons_id)
      c1 = Poll::Cache.get_constituency(user.constituency_ons_id)
      c2 = Poll::Cache.get_constituency(ons_id)

      old_type = c1&.voter_type(user) || "unknown"
      new_type = c2&.voter_type(user) || "unknown"

      "#{old_type}-2-#{new_type}"
    end

    def bucket_with(ons_id)
      [ category_with(ons_id), effort_reduction(ons_id), marginal_reduction(ons_id) ]
    end
  end

  class << self
    def order_keys_for_uniqueness(k1, k2)
      k1.hash > k2.hash ? [k1, k2] : [k2, k1]
    end

    # conversion_count is a hash, represent counts of confirmed and unconfirned swaps for a given group of voters.

    def score_conf_or_not_value(conversion_count, expected_good_bad_ratio)
      biased_not_conf_count = Float(expected_good_bad_ratio * (conversion_count[false] || 0))
      conf_count = conversion_count[true] || 0

      group_size = conversion_count[false] + conversion_count[true]

      # 0 = completely unconverted, 1 = completely converted, 0.5 = same score as you would expect from looking at all the results
      base_score = conf_count / (conf_count + biased_not_conf_count)

      return [base_score * 2, group_size] if group_size > SMALL_GROUP_THRESHOLD

      small_group_fudge_factor = group_size / Float(SMALL_GROUP_THRESHOLD)

      # 0 = completely unconverted, 1 = completely converted
      adjusted_base_score = (base_score - 0.5) * small_group_fudge_factor + 0.5

      return [adjusted_base_score * 2, group_size]
    end

    def explanation_lines
      [
        "SCORING PRINCIPLE: scores (after =>) represent relative success at converting proposed swaps into confirmed swaps.",
        "2.0 means 100% of them, 0.0 means none of them.",
        "Threshold between marginal and safe seat is a difference between the first two party votes of #{OnsConstituency::MARGINAL_THRESHOLD / 100.0}%",
        "",
        "Values before the => represent the two voters participating in the swap, and what they gain for their preferred party.",
        "E.g. fighting-2-winning indicates that voter's preferred party instead of getting a vote in marginal where they are fighting,",
        "instead gets a vote in a constituency where they are winning",
      ]
    end

    def swap_conversion_lookup
      choosing = User.left_joins(:outgoing_swap)
        .where("swaps.id IS NOT ?", nil)
        .where("ons_constituencies.ons_id IS NOT ?", nil)
        .where("constituencies_users.ons_id IS NOT ?", nil)
        .eager_load([
          { outgoing_swap: { chosen_user: :constituency } },
          :constituency
        ])

      total_confirmed = choosing.where(swaps: { confirmed: true }).count
      total_unconfirmed = choosing.where(swaps: { confirmed: false }).count
      expected_good_bad_ratio = total_confirmed / Float(total_unconfirmed)

      threeway = choosing.map do |chooser|
        chosen = chooser.outgoing_swap.chosen_user

        c2 = Poll::Cache.get_constituency(chooser.constituency_ons_id)
        c1 = Poll::Cache.get_constituency(chosen.constituency_ons_id)

        no_polls = c1.polls_count.zero? || c2.polls_count.zero?

        no_polls ? nil : [UserUtils.new(chooser).bucket_with(chosen.constituency_ons_id),
                          UserUtils.new(chosen).bucket_with(chooser.constituency_ons_id),
                          chooser.outgoing_swap.confirmed]
      end.compact.tally

      result = Hash.new{ |o, k| o[k] = Hash.new { |o, k| o[k] = 0 } }

      # now get the true/false values into a single hash for each group
      conversion_counts = threeway.each_with_object(result) do |(k, tally), r|
        chooser_bucket = k[0]
        chosen_bucket = k[1]
        conversion_or_not = k[2]

        # for figuring out if the swap is a conversion or not,
        # the order of the keys (swap proposer/swap receiver) doesn't matter,
        # both counts go into the same group
        new_key = order_keys_for_uniqueness(chooser_bucket, chosen_bucket)

        r[new_key][conversion_or_not] += tally
      end

      # now for each group, turn the pair of counts into a score, and return a hash of all of those
      conversion_counts.map do |(pair, conversion_count)|
        [pair, score_conf_or_not_value(conversion_count, expected_good_bad_ratio)]
      end.to_h
    end
  end
end
