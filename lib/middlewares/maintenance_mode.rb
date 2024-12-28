# Start server with maintenance mode
# env MAINTENANCE_MODE=true bin/rails s
# 
# Enter mintenance mode
# touch tmp/maintenance.txt
#
# Exit maintenance mode
# rm tmp/maintenance.txt
class MaintenanceMode
  def initialize(app)
    @app = app
  end

  def call(env)
    if env['PATH_INFO'] == '/up'
      @app.call(env)
    elsif File.exist?('tmp/maintenance.txt') || ENV['MAINTENANCE_MODE'] == 'true'
      [503, { 'Content-Type' => 'text/html' }, ['<html><body>We are currently undergoing maintenance. We apologize for any inconvenience this may cause. Please try again later.</body></html>']]
    else
      @app.call(env)
    end
  end
end
