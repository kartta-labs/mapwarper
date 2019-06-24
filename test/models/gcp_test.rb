require 'test_helper'

class GcpTest < ActiveSupport::TestCase
 
  setup do
    @map = FactoryGirl.create(:available_map)
  end

  test 'map from coords' do
    coords =  [{corner: "tr", lon: 12, lat:44 },{corner: "tl", lon: 33, lat:11 }]
    gcps =  Gcp.new_from_corner_coords(coords, @map)
    assert_not_nil gcps
    assert gcps.first.valid?
    assert gcps.first.soft
  end

end