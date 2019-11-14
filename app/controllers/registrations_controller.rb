class RegistrationsController < Devise::RegistrationsController

  protected

  def update_resource(resource, params)
    if current_user.provider
      resource.update_without_password(params)
    else
      super
    end
  end

end