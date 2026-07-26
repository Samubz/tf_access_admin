# frozen_string_literal: true

# POST /api/v1/private/device_token
# DELETE /api/v1/private/device_token
#
# Singular-resource endpoint: a User has at most one registered device token
# at a time (see openspec/changes/add-fcm-push-notifications/design.md
# Decision 2), so these actions always act on current_user's own token —
# no :id param is needed or accepted.
class Api::V1::Private::DeviceTokensController < Api::V1::Private::BaseController
  # Registering a new token replaces any previously registered one for this user.
  def create
    device_token = DeviceToken.find_or_initialize_by(user: current_user)
    device_token.assign_attributes(device_token_params.merge(last_seen_at: Time.current))

    if device_token.save
      render json: { data: { id: device_token.id, platform: device_token.platform } }, status: :created
    else
      render json: { error: device_token.errors.full_messages.to_sentence }, status: :unprocessable_entity
    end
  end

  def destroy
    current_user.device_token&.destroy

    head :no_content
  end

  private

  def device_token_params
    params.require(:device_token).permit(:token, :platform)
  end
end
