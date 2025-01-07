module ApplicationHelper
  def link_to_github_sign_in
    link_to "Sign in with GitHub", "/auth/github", class: "btn"
  end

  def link_to_google_sign_in
    link_to "Sign in with Google", "/auth/google_oauth2", class: "btn"
  end

  def link_to_facebook_sign_in
    link_to "Sign in with Facebook", "/auth/facebook", class: "btn"
  end
end
