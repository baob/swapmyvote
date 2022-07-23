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
      #
      def sort_hash_by_value(d)
        d.to_a.sort{ |x,y| x.last <=> y.last }.to_h
      end

      # explain yourself
      puts ""
      puts SwapSuccess.explanation_lines.join("\n")

      lookup = SwapSuccess.swap_success_lookup

      puts "\n\nsparse map (small groups under 50 eliminated)"
      pp sort_hash_by_value(lookup).select{ |x, y|  y[1] > 50 }.map{ |x,y| [x, [y[0].round(2), y[1]]]} ; nil
      all_scores = lookup.map{ |k,v| v }
      average = all_scores.map{ |s| s[0]}.sum/Float(all_scores.size)

      puts "\naverage = ", average

      all_p_swaps = PotentialSwap.eager_load(:source_user => :constituency, :target_user => :constituency)
      p_swap_scores = all_p_swaps.map do |ps|
        source_user_poll = Poll::Cache.get(constituency_ons_id: ps.source_user.constituency_ons_id, party_id: ps.source_user.preferred_party_id)
        target_user_poll = Poll::Cache.get(constituency_ons_id: ps.target_user.constituency_ons_id, party_id: ps.target_user.preferred_party_id)

        k1 = source_user_poll.bucket_with(ps.target_user.constituency_ons_id)
        k2 = target_user_poll.bucket_with(ps.source_user.constituency_ons_id)
        score = (lookup[ SwapSuccess.order_keys_for_uniqueness(k1,k2) ])
      end.compact.map{ |x, y| [x.round(2), y]}

      puts "\n\nFor all potential swaps, show percentage splits for each possible score.  score => percentage of potential swaps with that score"
      pp p_swap_scores.tally.sort.map{ |k,v| [k, (v*100.0/p_swap_scores.size).round(1)]}.to_h ; nil
      puts "percentage of potential swaps evaluated #{(p_swap_scores.size*100.0/all_p_swaps.size).round(1)}"
    end

  end
end
