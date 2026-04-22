class Avo::Actions::ResendInvitation < Avo::BaseAction
  self.name = "Resend Invitation"
  self.visible = -> do
    # In Avo 3, 'record' is available in ExecutionContext for row/record actions.
    # We use respond_to? to safely handle cases where it might be evaluated without a record context.
    record = respond_to?(:record) ? public_send(:record) : nil
    return false unless record.is_a?(::User)

    record.manager? && !record.registered?
  end

  def handle(models:, fields:, current_user:, resource:, **args)
    models.each do |user|
      user.send_manager_invitation
    end

    succeed "Invitations sent successfully!"
  end
end
