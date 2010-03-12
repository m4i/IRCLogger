class ChannelsController < ApplicationController
  def index
    @channels = Channel.find(:all, :order => 'name')
  end
end
