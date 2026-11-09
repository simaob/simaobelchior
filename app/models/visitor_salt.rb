# A random secret for each day, mixed into visitor hashes. Once a day's salt is
# deleted, its hashes can't be traced back to an IP address or linked to the
# same person on another day.
#
# Salts from earlier days are deleted when the first visit of a new day creates
# its salt, and by DeleteOldVisitorSaltsJob every 3 hours, for days nobody visits.
class VisitorSalt < ApplicationRecord
  def self.for(day)
    find_by(day: day)&.value || rotate(day)
  end

  def self.rotate(day)
    delete_before(day)
    create!(day: day, value: SecureRandom.hex(32)).value
  rescue ActiveRecord::RecordNotUnique
    # Another request created today's salt first
    find_by!(day: day).value
  end

  def self.delete_before(day)
    where(day: ...day).delete_all
  end
end
