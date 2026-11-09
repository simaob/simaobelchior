# Deletes visitor salts from earlier days, so none outlives its day even when
# nobody visits the site to replace it. Runs every hour, see config/recurring.yml.
class DeleteOldVisitorSaltsJob < ApplicationJob
  def perform
    VisitorSalt.delete_before(Date.current)
  end
end
