module Admin
  class ManagersController < BaseController
    def index
      @managers = User.managers
      @manager = User.new(role: :manager)
    end

    def new
      @manager = User.new(role: :manager)
    end

    def create
      @manager = User.find_or_initialize_by(email: manager_params[:email].to_s.strip.downcase)
      validate_manager_record!
      @manager.name = manager_params[:name]
      @manager.prepare_manager_invitation!(inviter: current_user)
      ManagerInvitationMailer.invite(@manager).deliver_now

      redirect_to admin_managers_path, notice: "Manager invitation sent to #{@manager.email}."
    rescue ActiveRecord::RecordInvalid
      @managers = User.managers
      render :index, status: :unprocessable_entity
    end

    private

    def manager_params
      params.require(:user).permit(:email, :name)
    end

    def validate_manager_record!
      return if @manager.new_record?
      return if @manager.manager? && !@manager.registered?

      @manager.errors.add(:email, "is already used by another active account") unless @manager.manager?
      @manager.errors.add(:email, "already belongs to a registered manager") if @manager.manager? && @manager.registered?
      raise ActiveRecord::RecordInvalid, @manager
    end
  end
end
