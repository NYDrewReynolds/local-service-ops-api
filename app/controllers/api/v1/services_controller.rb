class Api::V1::ServicesController < BaseController
  def index
    services = Service.order(:name)
    render_json({ services: services.as_json })
  end
end
