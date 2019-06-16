require 'test_helper'
require 'database_cleaner'

class VersionTest < ActiveSupport::TestCase
  PaperTrail.enabled = true
  PaperTrail.request.enabled = true
  self.use_transactional_fixtures = false
  DatabaseCleaner.strategy = :truncation

  def setup 
    @map = FactoryGirl.create(:available_map)
  end

  teardown do
    DatabaseCleaner.clean
  end

 
  test "changing map title gives new version" do
    new_title = "Warped map v2"
    old_title = @map.title
    @map.title =  new_title 
   
    @map.save
    assert_not_empty @map.versions
    assert_not_equal @map.title, old_title
    
    version = @map.versions.first
    assert_equal "create", version.event

    version = @map.versions.last
    assert_equal "update", version.event
    
    reified_map = version.reify
   
    assert_equal reified_map.title, old_title
    
    prev_map = @map.paper_trail.previous_version
    assert_equal prev_map, reified_map
  end


  test "adding and then updating a gcp creates a new map version" do
    gcp = Gcp.new(:x => 123, :y =>234,:lat=>1.1, :lon=>1.2)
    gcp.map = @map
    gcp.save
    
    gcp = Gcp.find(gcp.id)
    gcp.x = 567
    gcp.save
    
    m = Map.last.reload
    reified_gcp =  m.versions.last.reify(:has_many => true).gcps.first
    
    assert_equal 123, reified_gcp.x
  end

  test "reverting a map" do
    gcp = Gcp.new(:x => 123, :y =>234,:lat=>1.1, :lon=>1.2)
    gcp.map = @map
    gcp.save

    gcp2 = Gcp.new(:x => 222, :y =>222,:lat=>2.2, :lon=>2.2)
    gcp2.map = @map
    gcp2.save

    gcp3 = Gcp.new(:x => 333, :y =>333,:lat=>3.3, :lon=>3.3)
    gcp3.map = @map
    gcp3.save

    assert_equal 4, @map.versions.size
    assert_equal 3, @map.gcps.size
    assert_equal true, @map.gcps.include?(gcp3)

    #get the last but one version
    version_id =  @map.versions[-1].id
    version = PaperTrail::Version.find(version_id)

    reified_map = version.reify(:has_many => true)
    new_gcps = reified_map.gcps.to_a
    @map.gcps = new_gcps

    assert_equal 2, @map.gcps.size
    assert_equal false, @map.gcps.include?(gcp3)
  end
  


  
end