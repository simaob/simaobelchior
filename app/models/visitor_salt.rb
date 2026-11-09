# A random secret for each day, mixed into visitor hashes. The previous day's
# salt is deleted as soon as a new day starts, so a hash can't be traced back to
# an IP address or linked to the same person on another day.
class VisitorSalt < ApplicationRecord
  def self.for(day)
    find_by(day: day)&.value || rotate(day)
  end

  def self.rotate(day)
    where(day: ...day).delete_all
    create!(day: day, value: SecureRandom.hex(32)).value
  rescue ActiveRecord::RecordNotUnique
    # Another request created today's salt first
    find_by!(day: day).value
  end
end
