require_relative '../modules/swap_success'



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

      class User
        def dump_and_raise(poll)
          puts "votes nil problem"
          puts "poll", poll.attributes
          puts "user", self.attributes
          constituency = OnsConstituency.find_by(ons_id: poll.constituency_ons_id)
          puts "constituency name", constituency.attributes
          puts "constituency polls", constituency.polls.map(&:attributes)
          party = Party.find(preferred_party_id)
          puts "party", party.attributes
          raise "votes nil problem"
        end

        def two_polls_from_cache(ons_id)
          poll1 = Poll::Cache.get(constituency_ons_id: constituency_ons_id, party_id: preferred_party_id)
          poll2 = Poll::Cache.get(constituency_ons_id: ons_id, party_id: preferred_party_id)

          dump_and_raise(poll1) if poll1&.safe_votes.nil?
          dump_and_raise(poll2) if poll2&.safe_votes.nil?

          # note: poll from MY constituency is first
          [poll1, poll2]
        end

        def effort_reduction(ons_id)
          polls = two_polls_from_cache(ons_id)

          effort_reduction = polls.first.effort_to_win - polls.last.effort_to_win
          (effort_reduction/1000.0).round
        end

        def marginal_reduction(ons_id)
          polls = two_polls_from_cache(ons_id)

          marginal_reduction = (polls.first.effort_to_win.abs - polls.last.effort_to_win.abs)
          (marginal_reduction/1000.0).round
        end

        def category_with(ons_id)
          c1 = Poll::Cache.get_constituency(constituency_ons_id)
          c2 = Poll::Cache.get_constituency(ons_id)

          old_type = c1&.voter_type(self) || "unknown"
          new_type = c2&.voter_type(self) || "unknown"

          "#{old_type}-2-#{new_type}"
        end

        def bucket_with(ons_id)
          [ category_with(ons_id), effort_reduction(ons_id), marginal_reduction(ons_id) ]
        end
      end
    end

    desc "categorise swap types and show a success metric"
    task success_metrics: :analysis_setup do

      def sort_hash_by_value(d)
        d.to_a.sort{ |x,y| x.last <=> y.last }.to_h
      end

      # ---------------- SWAPS SCORING BASED ON CONFIRMED/UNCONFIRMED ---------------------

      # explain yourself
      puts ""
      puts SwapSuccess.explanation_lines.join("\n")

      lookup = SwapSuccess.swap_success_lookup

      puts "\n\nsparse map (small groups under 30 eliminated)"
      pp sort_hash_by_value(lookup).select{ |x, y|  y[1] >= 30 }.map{ |x,y| [x, [y[0].round(2), y[1]]]}

      all_scores = lookup.map{ |k,v| v }
      average = all_scores.map{ |s| s[0]}.sum/Float(all_scores.size)

      puts "\naverage = ", average
    end

    desc "classify swaps into buckets - figure out if the old potential swaps algorithm is good"
    task potential_swaps: :analysis_setup do

      # TODO: explain yourself

      lookup = SwapSuccess.swap_success_lookup

      # -------------------------------- POTENTIAL SWAPS ---------------------------------

      all_p_swaps = PotentialSwap
        .eager_load(:source_user => :constituency, :target_user => :constituency)
        .where("ons_constituencies.ons_id IS NOT ?", nil)
        .where("constituencies_users.ons_id IS NOT ?", nil) # .all.map{ |x| :fred}

      p_swap_scores = all_p_swaps.map do |ps|

        c2 = Poll::Cache.get_constituency(ps.target_user.constituency_ons_id)
        c1 = Poll::Cache.get_constituency(ps.source_user.constituency_ons_id)

        no_polls = c1.polls_count == 0 || c2.polls_count == 0

        unless no_polls
          k1 = ps.source_user.bucket_with(ps.target_user.constituency_ons_id)
          k2 = ps.target_user.bucket_with(ps.source_user.constituency_ons_id)
          score = (lookup[ SwapSuccess.order_keys_for_uniqueness(k1,k2) ])
        end
      end.compact.map{ |x, y| x.round(1)} # discard the group count so that same score values get merged in the tally

      puts "\n\nFor all potential swaps, show percentage splits for each possible score.  score => percentage of potential swaps with that score"
      pp p_swap_scores.tally.sort.map{ |k,v| [k, (v*100.0/p_swap_scores.size).round(1)]}.to_h ; nil
      puts "percentage of potential swaps evaluated #{(p_swap_scores.size*100.0/all_p_swaps.size).round(1)}"
    end

    desc "classify swaps into buckets - figure out if the success over every potential swap"
    task all_possible_swap_types: :analysis_setup do

      # TODO: explain yourself

      lookup = SwapSuccess.swap_success_lookup

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
