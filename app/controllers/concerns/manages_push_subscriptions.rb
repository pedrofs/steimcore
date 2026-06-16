# Registers/removes the current browser's push endpoint for whoever is signed
# in. Both the trainer (`PushSubscriptionsController`) and the student
# (`Student::PushSubscriptionsController`) mount this — each within its own auth
# boundary — so the subscription is always owned by the session's principal
# (`Current.session.authenticatable`).
#
# These actions are hit by `fetch` from the service-worker registration flow,
# not by Inertia visits, so they answer with bare 204s instead of redirects.
module ManagesPushSubscriptions
  extend ActiveSupport::Concern

  def create
    # Upsert by endpoint, which is globally unique: the same browser re-logging
    # in as a different principal reuses the endpoint, so reclaim ownership
    # rather than colliding on the unique index.
    subscription = PushSubscription.find_or_initialize_by(endpoint: subscription_params[:endpoint])
    subscription.update!(subscription_params.merge(authenticatable: principal, user_agent: request.user_agent))

    head :no_content
  end

  def destroy
    principal.push_subscriptions.where(endpoint: params[:endpoint]).destroy_all

    head :no_content
  end

  private
    def principal
      Current.session.authenticatable
    end

    def subscription_params
      params.expect(push_subscription: [ :endpoint, :p256dh_key, :auth_key ])
    end
end
