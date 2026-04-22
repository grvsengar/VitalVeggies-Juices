class ManagerInvitationMailer < ApplicationMailer
  def invite(manager)
    @manager = manager
    @inviter = manager.invited_by

    mail(
      to: manager.email,
      subject: "Complete your Vital Veggies manager registration"
    )
  end
end
