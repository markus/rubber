# This is a sample Capistrano config file for rubber

set :rails_env, (ENV["RAILS_ENV"] ||= 'production')

on :load do
  set :application, rubber_cfg.environment.bind().app_name
  set :deploy_to,     "/mnt/#{application}-#{rails_env}"
end

# Use a simple directory tree copy here to make demo easier.
# You probably want to use your own repository for a real app
require 'capistrano/noscm'
set :scm, :noscm
set :deploy_via, :copy
set :copy_strategy, :export

# Easier to do system level config as root - probably should do it through
# sudo in the future.  We use ssh keys for access, so no passwd needed
set :user, 'root'
set :password, nil

# Use sudo with user rails for cap deploy:[stop|start|restart]
# This way exposed services (mongrel) aren't running as a privileged user
set :use_sudo,      true
set :runner,        'rails'

# How many old releases should be kept around when running "cleanup" task
set :keep_releases, 3

# Lets us work with staging instances without having to checkin instance file
# between create and bootstrap, as well as during a deploy.  This gives us the
# convenience of not having to checking instance file for staging, as wel as 
# the safety of forcing it to be checked in for production.
set :push_instance_config, rails_env != 'production'

# Allows the tasks defined to fail gracefully if there are no hosts for them.
# Comment out or use "required_task" for default cap behavior of a hard failure
rubber.allow_optional_tasks(self)

# =============================================================================
# TASKS
# =============================================================================


Dir["#{File.dirname(__FILE__)}/rubber/deploy-*.rb"].each do |deploy_file|
  load deploy_file
end

# Don't want to do rubber:config for update_code as that tree isn't official
# until it is 'committed' by the symlink task (and doing so causes it to run
# for bootstrap_db which should only config the db config file).  However, 
# deploy:migrations doesn't call update, so we need an additional trigger for
# it
after "deploy:update", "rubber:config"
before "deploy:migrate", "rubber:config"

before "rubber:pre_start", "setup_perms"
before "rubber:pre_restart", "setup_perms"
after "deploy", "deploy:cleanup"

# In cap 2.3, deploy:setup runs as "runner" which doesn't have perms to
# create deploy dir, so override cap behavior
before "deploy:setup", "as_root"
before "deploy:cleanup", "as_root"
after "deploy:setup", "not_root"
after "deploy:setup", "not_root"
task :as_root do
  set :use_sudo, falseend
task :not_root do
  set :use_sudo, true
end

# Fix perms because we start server as rails user, but migrate as root,
# server needs to be able to write logs, etc.
task :setup_perms do
  run "find #{shared_path} -name cached-copy -prune -o -print | xargs chown #{runner}:#{runner}"
  run "chown -R #{runner}:#{runner} #{current_path}/tmp"
end


after "rubber:install_packages", "custom_install_base"

task :custom_install_base do
  # add the rails user for running app server with
  appuser = "rails"
  run "if ! id #{appuser} &> /dev/null; then adduser --system --group #{appuser}; fi"
end

