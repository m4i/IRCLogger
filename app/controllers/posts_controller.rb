class PostsController < ApplicationController
  def create
    data = JsonParser.new.parse(request.raw_post)

    if channel = Channel.find_by_name(data['channel'])
      post = channel.posts.build(data.slice('command', 'message'))
      if post.save
        render :json => post, :status => :created
      else
        render :json => post.errors, :status => :unprocessable_entity
      end
    else
      errors = [['channel', %|can't find channel "#{data['channel']}"|]]
      render :json => errors, :status => :unprocessable_entity
    end
  end
end
