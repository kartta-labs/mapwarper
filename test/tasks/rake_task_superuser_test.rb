require 'test_helper'
require 'rake'

class RakeTaskSuperuserTest < ActiveSupport::TestCase
  setup do
    ApplicationName::Application.load_tasks if Rake::Task.tasks.empty?
    FactoryGirl.create(:admin_role)
    FactoryGirl.create(:super_user_role)
  end

  test "set super user" do
    user = FactoryGirl.create(:provider)
    assert user.roles.empty?
    ENV['EMAIL'] = user.email
    Rake::Task['warper:set_superuser'].invoke
    
    user.reload
    assert !user.roles.empty?
    assert_equal 2, user.roles.count
    assert user.has_role?("super user")
    assert user.has_role?("administrator")
  end

  test "create new super user" do
    assert_difference('User.count', 1) do
     Rake::Task['warper:create_superuser'].invoke
    end

    user = User.last
    assert !user.roles.empty?
    assert_equal 2, user.roles.count
    assert user.has_role?("super user")
    assert user.has_role?("administrator")
  end

end
