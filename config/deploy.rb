# config valid for current version and patch releases of Capistrano
lock "~> 3.16.0"

set :application, "simaobelchior"
set :repo_url, "git@github.com:simaob/simaobelchior.git"

set :rvm_ruby_version, '2.7.4'
set :user, 'simaob'

set :linked_files, %w{config/master.key}
set :passenger_restart_with_touch, true
