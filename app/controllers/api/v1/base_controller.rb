module Api
  module V1
    class BaseController < ApplicationController
      before_action :require_admin!

      private

      def render_json(data, status: :ok)
        render json: data, status: status
      end
    end
  end
end
