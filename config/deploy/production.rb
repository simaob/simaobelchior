role :app, %w{188.166.121.220}
role :web, %w{188.166.121.220}
role :db,  %w{188.166.121.220}


server '188.166.121.220', user: fetch(:user), roles: %w{web app}

set :rails_env, :production

set :deploy_to, "/home/#{fetch(:user)}/simaobelchior"
