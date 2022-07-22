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

    desc "expermient with metrics - classify swaps into buckets - figure out if the old potential swaps algorithm is good"
    task metrics_potential_swaps: :environment do

      class User
        def score_against(ons_id)
          poll1 = Poll::Cache.get(constituency_ons_id: constituency_ons_id, party_id: preferred_party_id)
          poll2 = Poll::Cache.get(constituency_ons_id: ons_id, party_id: preferred_party_id)

          effort_reduction = (poll1&.votes.nil? || poll2&.votes.nil?) ? -9999 : [poll1.effort_to_win, 0].max - [poll2.effort_to_win, 0].max
          (effort_reduction/1000.0).round
        end

        def bucket_with(ons_id)
          [ category_with(ons_id), score_against(ons_id)]
        end

        def category_with(ons_id)
          score = score_against(ons_id)

          c2 = Poll::Cache.get_constituency(ons_id)
          c1 = Poll::Cache.get_constituency(constituency_ons_id)

          old_type = c1&.voter_type(self) || "unknown"
          new_type = c2&.voter_type(self) || "unknown"

          "#{old_type}-2-#{new_type}"
        end

      end

      def sort_hash_by_value(d)
        d.to_a.sort{ |x,y| x.last <=> y.last }.to_h
      end

      puts "\nSCORING PRINCIPLE: scores (after =>) represent relative success at turning proposed swaps into confirmed swaps."
      puts "2.0 means 100% of them, 0.0 means none of them."
      puts "Threshold between marginal and safe seat is a difference between the first two party votes of #{OnsConstituency::MARGINAL_THRESHOLD/100.0}%"

      puts "\nValues before the => represent the two voters participating in the swap, and what they gain for their preferred party."
      puts "E.g. fighting-2-winning indicates that voter's preferred party instead of getting a vote in marginal where they are fighting,"
      puts "instead gets a vote in a constituency where they are winning"

      lookup = SwapSuccess.swap_success_lookup

      puts "\n\nsparse map"
      pp sort_hash_by_value(lookup) ; nil
      all_scores = lookup.map{ |k,v| v }
      average = all_scores.sum/Float(all_scores.size)

      puts "\naverage = ", average

      all_p_swaps = PotentialSwap.eager_load(:source_user => :constituency, :target_user => :constituency)
      p_swap_scores = all_p_swaps.map do |ps|
        k1 = ps.source_user.bucket_with(ps.target_user.constituency_ons_id)
        k2 = ps.target_user.bucket_with(ps.source_user.constituency_ons_id)
        score = (lookup[ SwapSuccess.order_keys_for_uniqueness(k1,k2) ])
      end.compact.map{ |x| x.round(2)}

      puts "\n\nFor all potential swaps, show percentage splits for each possible score.  score => percentage of potential swaps with that score"
      pp p_swap_scores.tally.sort.map{ |k,v| [k, (v*100.0/p_swap_scores.size).round(1)]}.to_h ; nil
      puts "percentage of potential swaps evaluated #{(p_swap_scores.size*100.0/all_p_swaps.size).round(1)}"
    end

  end
end
