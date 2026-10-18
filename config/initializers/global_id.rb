# Rich text can hold attachments pointing at models that no longer exist (for
# example a YouTube "Embed" model from an old experiment). GlobalID raises
# NameError for those, which crashes any page rendering the article. Raising
# RecordNotFound instead lets Action Text fall back to a missing attachable,
# as it already does for deleted records.
class MissingModelTolerantLocator < GlobalID::Locator::UnscopedLocator
  def locate(gid, options = {})
    raise ActiveRecord::RecordNotFound, "#{gid.model_name} no longer exists" unless gid.model_name.safe_constantize

    super
  end
end

GlobalID::Locator.default_locator = MissingModelTolerantLocator.new
