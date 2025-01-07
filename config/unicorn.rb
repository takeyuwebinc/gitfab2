rails_env = ENV['RAILS_ENV'] || 'production'
workers_procs = { production: 5, staging: 2 }
workers_procs.default = 2
worker_processes workers_procs[rails_env.to_sym]

app_directory = ENV.fetch('WORKDIR') { '/usr/local/rails_apps/gitfab2/current' }
working_directory app_directory # available in 0.94.0+

listen_address = ENV.fetch('LISTEN_ADDRESS') { '/tmp/unicorn_gitfab2.sock' }
listen listen_address, backlog: 128

timeout 3000

pid ENV.fetch('PID') { '/tmp/unicorn_gitfab2.pid' }

if rails_env.to_s != 'production'
  stderr_path "#{app_directory}/log/unicorn_#{rails_env}.log"
  stdout_path "#{app_directory}/log/unicorn_#{rails_env}.log"
end

preload_app true
GC.respond_to?(:copy_on_write_friendly=) and
  GC.copy_on_write_friendly = true

before_exec do |_server|
  ENV['BUNDLE_GEMFILE'] = "#{app_directory}/Gemfile"
end

before_fork do |server, worker|
  #  defined?(ActiveRecord::Base) and
  #    ActiveRecord::Base.connection.disconnect!

  old_pid = "#{server.config[:pid]}.oldbin"
  if old_pid != server.pid
    begin
      sig = (worker.nr + 1) >= server.worker_processes ? :QUIT : :TTOU
      Process.kill(sig, File.read(old_pid).to_i)
    rescue Errno::ENOENT, Errno::ESRCH
    end
  end

  sleep 1
end

after_fork do |_server, _worker|
  #  defined?(ActiveRecord::Base) and
  #    ActiveRecord::Base.establish_connection
end
