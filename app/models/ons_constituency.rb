class OnsConstituency < ApplicationRecord
  NUMBER_OF_UK_CONSTITUENCIES = 650
  has_many :polls,
           foreign_key: "constituency_ons_id",
           primary_key: "ons_id",
           dependent: :destroy

  has_many :recommendations,
           primary_key: "ons_id",
           foreign_key: "constituency_ons_id",
           dependent: :destroy

  def parties_by_marginal_score
    polls_by_marginal_score.map(&:party)
  end

  def polls_by_marginal_score
    return @polls_by_marginal_score if defined? @polls_by_marginal_score
    @polls_by_marginal_score = polls.order(:marginal_score)
  end

  MARGINAL_THRESHOLD = 3000

  def marginal?
    polls_by_marginal_score.first.marginal_score <= MARGINAL_THRESHOLD
  end

  def marginal_known?
    polls_by_marginal_score.count > 0
  end

  def marginal_degree
    return ""
    # msf = polls_by_marginal_score.first.marginal_score
    # return "" if msf > MARGINAL_THRESHOLD
    # return "-loose" if msf > MARGINAL_THRESHOLD/2
    # return "-tight" if msf > 400
    # return "-ultra"
  end

  def winner_for_user?(user)
    marginal_known? && !marginal? && parties_by_marginal_score.first.id == user.preferred_party.id
  end

  def loser_for_user?(user)
    marginal_known? && !winner_for_user?(user) && !marginal_for_user?(user)
  end

  def marginal_for_user?(user)
    marginal_known? && marginal? && parties_by_marginal_score[0..1].map(&:id).include?(user.preferred_party.id)
  end

  def voter_type(user)
    return "wfl_unknown_" + user.preferred_party.name if !marginal_known?
    if marginal_for_user?(user)
      if !marginal?
        dump_before_raise(user)
        raise "what went wrong to classify this as fighting_safe"
      end
      return "fighting"
    elsif winner_for_user?(user)
      return "winning"
    elsif loser_for_user?(user)
      return "losing"
    end
  end

  def dump_before_raise(user)
    puts "\n\n"
    puts user.attributes
    puts "marginal?", marginal? if  marginal_known?
    puts "marginal_known?", marginal_known?
    puts "winner_for_user?(user)", winner_for_user?(user)
    puts "loser_for_user?(user)", loser_for_user?(user)
    puts "marginal_for_user?(user)", marginal_for_user?(user)
    # puts user.party
    puts self.attributes
    puts polls.map(&:attributes)
  end

  def constituency_type
    return "ms_unknown" if !marginal_known?
    (marginal? ? "marginal" : "safe")  + marginal_degree
  end

  def combined_type(u)
    voter_type(u) + "-" + constituency_type
  end
end
