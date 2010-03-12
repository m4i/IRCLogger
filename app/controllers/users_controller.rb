class UsersController < ApplicationController
  def index
    @users = User.find(:all, :order => 'name')
  end
end
