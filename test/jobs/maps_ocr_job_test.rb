require 'test_helper'
require "google/cloud/vision"

Rails.application.config.active_job.queue_adapter = :inline


class MapsOcrJobTest < ActiveJob::TestCase
  setup do
    @map =  FactoryGirl.create(:warped_map)

    MapsOcrJob.any_instance.stubs(:google_image_annotate).returns( JSON.parse( {"responses":[{"full_text_annotation":{"pages":[{"blocks":[{"paragraphs":[{"words":[{"symbols":[{"text":"F"},{"text":"O"},{"text":"O"},{"text":"B"},{"text":"A"},{"text":"R"}]}],"confidence":0.99}]}]}]}}]}.to_json, object_class: OpenStruct) )
    MapsOcrJob.any_instance.stubs(:call_google_geocode).returns("dummy text")

  end
  
  test 'that map gets an ocr result' do
    MapsOcrJob.perform_now(@map)
    assert_not @map.reload.ocr_result.blank?
    assert_equal "foobar",  @map.reload.ocr_result
  end

  test 'the job gets scheduled' do
    assert_enqueued_with(job: MapsOcrJob) do
      @map.run_ocr
    end
  end
end

# stripped down version of json response. Note that the Ruby client converts fullTextAnnotation to full_text_annotation
# {
#   "responses": [
#     {
#       "fullTextAnnotation": {
#         "pages": [
#           {
#             "blocks": [
#               {
#                 "paragraphs": [
#                   {
#                     "words": [
#                       {
#                         "symbols": [
#                           {
#                             "text": "F"
#                           },
#                           {
#                             "text": "O"
#                           },
#                           {
#                             "text": "O"
#                           },
#                           {
#                             "text": "B"
#                           },
#                           {
#                             "text": "A"
#                           },
#                           {
#                             "text": "R"
#                           }
#                         ]
#                       }
#                     ],
#                     "confidence": 0.99
#                   }
#                 ]
#               }
#             ]
#           }
#         ]
#       }
#     }
#   ]
# }