class Post < ActiveRecord::Base
  belongs_to :channel

  validates_presence_of :command, :channel_id, :message
  validates_inclusion_of :command, :in => [Net::IRC::Constants::PRIVMSG, Net::IRC::Constants::NOTICE]
  validates_length_of :message, :minimum => 1
  validates_each :channel_id do |record, attr, value|
    unless Channel.exists?(value)
      raise "cannot find channels.id = #{value}"
    end
  end

  # まだ post していないレコード
  named_scope :unposted,
    :include    => :channel,
    :conditions => { :posted_at => nil },
    :order      => 'posts.created_at, posts.id'

  # post 済みにする
  def posted!
    update_attributes!(:posted_at => Time.now)
  end
end
