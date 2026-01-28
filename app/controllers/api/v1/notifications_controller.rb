module Api
  module V1
    class NotificationsController < BaseController
      def index
        notifications = Notification.includes(:lead, :job).order(created_at: :desc)
        render_json({ notifications: notifications.as_json(include: %i[lead job]) })
      end

      def show
        notification = Notification.includes(:lead, :job).find(params[:id])
        render_json({ notification: notification.as_json(include: %i[lead job]) })
      end
    end
  end
end
