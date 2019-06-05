require 'test_helper'
require "google/cloud/vision"

Rails.application.config.active_job.queue_adapter = :inline


class MapsOcrJobTest < ActiveJob::TestCase
  setup do
    @map =  FactoryGirl.create(:warped_map)
    MapsOcrJob.any_instance.stubs(:google_image_annotate).returns( JSON.parse({responses: [ text_annotations: [ description: "FOOBAR"]]}.to_json, object_class: OpenStruct) )
    MapsOcrJob.any_instance.stubs(:call_google_geocode).returns("dummy text")

  end
  
  test 'that map gets an ocr result' do
    MapsOcrJob.perform_now(@map)
    assert_not @map.reload.ocr_result.blank?
  end

  test 'the job gets scheduled' do
    assert_enqueued_with(job: MapsOcrJob) do
      @map.run_ocr
    end
  end
end
