select users.id, name, email, swaps.id AS swaps_id
from users, swaps
left join parties as partyup on users.willing_party_id = partyup.id
left join parties as partydown on users.preferred_party_id = partydown.id
left join ons_constituencies on users.constituency_ons_id = ons_constituencies.ons_id
where ((users.swap_id = swaps.id) or (users.id = swaps.chosen_user_id))
and swaps.confirmed = true
and email is not null and email != ''




select count(users.id, name, email, swaps.id)
from users, swaps
left join parties as partyup on users.willing_party_id = partyup.id
left join parties as partydown on users.preferred_party_id = partydown.id
left join ons_constituencies on users.constituency_ons_id = ons_constituencies.ons_id
where ((users.swap_id = swaps.id) or (users.id = swaps.chosen_user_id))
and swaps.confirmed = true
and email is not null and email != ''



select users.id, swaps.id, willing_party_id, preferred_party_id
from users, swaps
where ((users.swap_id = swaps.id) or (users.id = swaps.chosen_user_id))
and swaps.confirmed = true


select user_id, swap_id, willing_party_id, preferred_party_id, swing_raw.ons_id, parties.id as party_id,
  (CASE WHEN parties.id = willing_party_id THEN 1 else 0 end) as partyup,
  (CASE WHEN parties.id = preferred_party_id THEN 1 else 0 end) as partydown
from (
  select users.id as user_id, swaps.id as swap_id, willing_party_id, preferred_party_id, constituency_ons_id as ons_id
  from users, swaps
  where ((users.swap_id = swaps.id) or (users.id = swaps.chosen_user_id))
  and swaps.confirmed = true
  limit 10
) as swing_raw
left join parties  on swing_raw.willing_party_id = parties.id or swing_raw.preferred_party_id = parties.id
left join ons_constituencies on swing_raw.ons_id = ons_constituencies.ons_id

select swaps.id as swap_id, usersa.id as usersa_id, usersb.id as usersb_id,
  usersa.constituency_ons_id as onsa_id, usersb.constituency_ons_id as onsb_id,
  usersa.willing_party_id as party_up_a_id, usersb.willing_party_id as party_up_b_id
from swaps
left join users as usersa on usersa.swap_id = swaps.id
left join users as usersb on swaps.chosen_user_id = usersb.id
  limit 10
