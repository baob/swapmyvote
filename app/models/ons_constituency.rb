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

  MARGINAL_THRESHOLD = 2000

  def marginal?
    polls_by_marginal_score.first.marginal_score <= MARGINAL_THRESHOLD
  end

  def marginal_known?
    polls_by_marginal_score.count > 0
  end

  def marginal_degree
    return ""
    # msf = polls_by_marginal_score.first.marginal_score
    # return "" if msf > 3000
    # return "-C" if msf > 2000
    # return "-B" if msf > 1000
    # return "-A"
  end

  def winner_for_user?(user)
    marginal_known? && !marginal? && parties_by_marginal_score.first.id == user.preferred_party_id
  end

  def loser_for_user?(user)
    marginal_known? && !winner_for_user?(user) && !marginal_for_user?(user)
  end

  def marginal_for_user?(user)
    marginal_known? && marginal? && parties_by_marginal_score[0..1].map(&:id).include?(user.preferred_party_id)
  end

  def user_is_defeater?(user)
    marginal_known? && !winner_for_user?(user) && !marginal_for_user?(user) && parties_by_marginal_score[0..1].map(&:id).include?(user.willing_party_id)
  end

  def voter_type(user)
    return "wfl_unknown_" + user.preferred_party.name if !marginal_known?
    if winner_for_user?(user)
      return "winning"
    elsif marginal_for_user?(user)
      return "fighting"
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
    puts "user_is_defeater?(user)", user_is_defeater?(user)
    # puts user.party
    puts self.attributes
    puts polls.map(&:attributes)
  end

  def user_party_vote_share(user)
    # raise "User does not have a preferred party" if user.preferred_party.nil?
    # raise "constituency does not have poll predictions" unless marginal_known?
    return 0 if user.preferred_party.nil?
    return 0 unless marginal_known?
    poll = polls.where(party: user.preferred_party).first
    poll.nil? ? 0 : poll.votes
  end

  def constituency_type
    return "ms_unknown" if !marginal_known?
    (marginal? ? "marginal" : "safe") + marginal_degree
  end

  def combined_type(u)
    voter_type(u) + "-" + constituency_type
  end
end
