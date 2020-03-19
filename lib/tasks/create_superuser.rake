#runs once to set up the super user with a random password

namespace :warper do

  desc "Sets an existing user to have super user and administrator roles. rake warper:set_superuser EMAIL=name@example.com"
  task :set_superuser => :environment do
    email = ENV['EMAIL']  || nil
    break unless email

    return false unless User.exists? email: email

    user = User.find_by_email(email)

    admin_role = Role.find_by_name('administrator')
    super_role = Role.find_by_name('super user')

    [admin_role, super_role].each do | role |
      unless user.has_role?(role.name)
        user.roles << role
      end
    end


  end

  desc "Sets up an initial super user with random password"
  task :create_superuser  => :environment do
    puts 'Creating Superuser'
    if User.exists? login: "super"
      puts "Super User already exists"
      return false
    end
    
    require 'securerandom'

    pass = SecureRandom.urlsafe_base64(rand(36..56))
    puts "PASSWORD is #{pass} make a note of this! Email is super@example.com"

    user = User.new
    user.login = "super"
    user.email = "super@example.com"
    
    user.password = pass
    user.password_confirmation = pass
    user.save
    user.confirmed_at = Time.now
    user.save
    
    role = Role.find_by_name('super user')
    user = User.find_by_login('super')
    
    permission  = Permission.new
    permission.role = role
    permission.user = user
    permission.save
    
    role = Role.find_by_name('administrator')
    permission = Permission.new
    permission.role = role
    permission.user = user
    permission.save

  end

end


