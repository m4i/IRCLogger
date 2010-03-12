require 'test_helper'

class PostsControllerTest < ActionController::TestCase
  def test_should_create_post
    @request.env['RAW_POST_DATA'] = {
      'command' => 'PRIVMSG',
      'channel' => '#staff',
      'message' => 'おはよう',
    }.to_json

    assert_difference('Post.count') do
      post :create
    end

    assert_response :created
  end
end
