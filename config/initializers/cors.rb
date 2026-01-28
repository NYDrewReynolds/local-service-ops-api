Rails.application.config.middleware.insert_before 0, Rack::Cors do
  allow do
    default_origins = ["http://localhost:8080", "http://localhost:3000"]
    env_origins = ENV.fetch("DASHBOARD_ORIGINS", "").split(",").map(&:strip).reject(&:empty?)

    origins(*(default_origins + env_origins))
    resource "/api/*",
             headers: :any,
             methods: %i[get post patch put delete options head],
             credentials: true
  end
end
