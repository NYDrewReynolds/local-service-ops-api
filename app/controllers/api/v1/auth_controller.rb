module Api
  module V1
    class AuthController < ApplicationController
      skip_before_action :verify_authenticity_token

      def login
        admin = AdminUser.find_by(email: params[:email])

        if admin&.authenticate(params[:password])
          session[:admin_user_id] = admin.id
          render json: { admin_user: { id: admin.id, email: admin.email } }
        else
          render json: { error: "Invalid credentials" }, status: :unauthorized
        end
      end

      def logout
        session.delete(:admin_user_id)
        render json: { ok: true }
      end
    end
  end
end
