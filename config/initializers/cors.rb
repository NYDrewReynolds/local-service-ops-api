Rails.application.config.middleware.insert_before 0, Rack::Cors do
  allow do
    origins ENV.fetch("DASHBOARD_ORIGIN", "http://localhost:3000")
    resource "/api/*",
             headers: :any,
             methods: %i[get post patch put delete options head],
             credentials: true
  end
end
