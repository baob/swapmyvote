# This loads the tactical voting recommandations from StopTheTories.vote
# into the recommendations table

require_relative "tactical_vote_stt_csv"
require_relative "mysociety_constituencies_csv"

class TacticalVoteSttRecs
  attr_reader :advisor, :mysoc_constituencies

  ACCEPTABLE_NON_PARTY_ADVICE = [:heart, :none]
  SMV_CODES_BY_ADVICE_TEXT = {
    lab: :lab,
    snp: :snp,
    ld: :libdem,
    pc: :plaid,
    green: :green
  }

  def initialize
    @advisor = TacticalVoteSttCsv.new
    @mysoc_constituencies = MysocietyConstituenciesCsv.new
  end

  # rubocop:disable Metrics/MethodLength
  def load
    ons_id_by_mysoc_short_code = {}

    mysoc_constituencies.each do |constituency|
      ons_id_by_mysoc_short_code[constituency[:short_code]] = constituency[:ons_id]
    end

    parties_by_smv_code = Party.all.each_with_object({}) do |party, lookup|
      lookup[party.smv_code.to_sym] = party
    end

    included_parties = Party.where.not({ smv_code: [:con, :reform] }).all

    not_recognised = Set.new

    advisor.data.each do |row|
      ons_id = ons_id_by_mysoc_short_code[row[:mysoc_short_code]]

      unless ons_id
        puts "\nIGNORING: Constituency lookup failed for #{row}."
        next
      end

      rec_key = { constituency_ons_id: ons_id, site: advisor.site }
      rec = Recommendation.find_or_initialize_by(rec_key)
      source_advice = row[:advice]

      # ------------------------------------------------------------------------

      canonical_advice = source_advice.strip.downcase.parameterize(separator: "_").to_sym
      party_smv_code = SMV_CODES_BY_ADVICE_TEXT[canonical_advice]
      non_party_advice = ACCEPTABLE_NON_PARTY_ADVICE.include?(canonical_advice) ? canonical_advice : nil

      if party_smv_code && parties_by_smv_code[party_smv_code]
        party = parties_by_smv_code[party_smv_code]
        rec.text = party.name
        rec.update_parties([party])
      elsif non_party_advice && non_party_advice == :heart
        rec.text = "Any"
        rec.update_parties(included_parties)
      else
        # if we can't turn it into a recommendation we must delete any existing entry
        unless rec.id.nil?
          rec.update_parties([]) # keep none, delete the rest
          rec.delete
          print "X" # to signify delete
        end

        not_recognised.add({ advice: source_advice, canonical_advice: canonical_advice })

        next
      end

      # ------------------------------------------------------------------------

      rec.save!
      print "." # to signify update
    end

    puts "\n\nVoting advice not recognised #{not_recognised.to_a}" if not_recognised.size.positive?
  end
end
