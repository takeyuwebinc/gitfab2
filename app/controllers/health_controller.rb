class HealthController < ApplicationController
  def show
    render plain: "OK", status: :ok
  end
end
