# config valid for current version and patch releases of Capistrano
lock "~> 3.12.0"

set :application, "simaobelchior"
set :repo_url, "git@github.com:simaob/simaobelchior.git"

set :rvm_ruby_version, '2.6.3'
set :user, 'simaob'

set :linked_files, %w{config/master.key}
