class OnsConstituency < ApplicationRecord
  NUMBER_OF_UK_CONSTITUENCIES = 650
  MARGINAL_THRESHOLD = 1000

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
    @polls_by_marginal_score = polls.order(:marginal_score).all
  end

  def marginal?
    return @is_marginal if defined?(@is_marginal)
    @is_marginal = polls_by_marginal_score.first.marginal_score <= MARGINAL_THRESHOLD
  end

  def marginal_known?
    return @marginal_known if defined?(@marginal_known)
    @marginal_known = polls_by_marginal_score.count > 0
  end

  # These next 4 methods use poll as a proxy for user, since they both identify party and constituency
  # this is a bit indirect for regular use, but has major benefits when running analysis over the whole db

  def winner_for_user?(poll)
    marginal_known? && !marginal? && polls_by_marginal_score.first.party_id == poll.party_id
  end

  def loser_for_user?(poll)
    marginal_known? && !winner_for_user?(poll) && !marginal_for_user?(poll)
  end

  def marginal_for_user?(poll)
    marginal_known? && marginal? && polls_by_marginal_score[0..1].map(&:party_id).include?(poll.party_id)
  end

  def voter_type(poll)
    return "unknown" unless marginal_known?
    if winner_for_user?(poll)
      return "winning"
    elsif marginal_for_user?(poll)
      return "fighting"
    elsif loser_for_user?(poll)
      return marginal? ? "losing-m" : "losing-s"
    end
  end
end
