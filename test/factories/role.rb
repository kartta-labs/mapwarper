FactoryGirl.define do

  factory :admin_role, :class => Role do
    name :administrator
  end

  factory :super_user_role, :class => Role do
    name "super user"
  end
  
  factory :editor_role, :class => Role do
    name :editor
  end
  
end