class Channel < ActiveRecord::Base
  has_many :messages
  has_many :posts

  validates_presence_of :name
  validates_length_of   :name, :minimum => 1
  validates_length_of   :topic, :allow_nil => true, :minimum => 1

  class << self
    # 全チャンネル名
    def names
      all.map(&:name)
    end

    # find_by_name or create!
    def find_or_create!(name)
      find_by_name(name) || create!(:name => name)
    end
  end

  # topic の更新
  def update_topic!(topic)
    topic = nil if topic.blank?
    update_attributes!(:topic => topic)
  end
end
