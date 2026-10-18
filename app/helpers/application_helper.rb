module ApplicationHelper
  def nav_link(name, path, active: false)
    link_to name, path, class: "site-nav__link", aria: { current: ("page" if active) }
  end

  # The contact call-to-action sits in the footer on every public page except
  # the homepage, which has its own contact section.
  def footer_cta?
    controller_path == "articles" || (controller_path == "home" && action_name == "about")
  end
end
