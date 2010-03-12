class Message < ActiveRecord::Base
  belongs_to :channel
  belongs_to :user

  validates_presence_of :command, :channel_id, :user_id, :nickname, :message, :timestamp
  validates_length_of :command,  :minimum => 1
  validates_length_of :nickname, :minimum => 1
  validates_each :channel_id do |record, attr, value|
    unless Channel.exists?(value)
      raise "cannot find channels.id = #{value}"
    end
  end
  validates_each :user_id do |record, attr, value|
    unless User.exists?(value)
      raise "cannot find users.id = #{value}"
    end
  end

  named_scope :by_channel, proc {|c| { :conditions => { :channel_id => c.id }} }
  named_scope :by_user,    proc {|u| { :conditions => { :user_id    => u.id }} }

  # 途中で bot が作成される場合もあるため Hash でなく proc で指定
  named_scope :without_bot, proc {
    User.bot ? { :conditions => ['user_id != ?', User.bot.id] } : {}
  }


  class << self
    # 指定した期間の Message を返す
    def find_all_by_period(from_date, to_date = from_date)
      all(
        :include    => [:channel, :user],
        :order      => 'messages.timestamp, messages.id',
        :conditions => [
          'messages.timestamp BETWEEN ? AND ?',
          from_date.beginning_of_day.utc, to_date.end_of_day.utc,
        ]
      )
    end

    # date の直前の Message がある日を返す
    def day_before(date)
      (row = first(
        :conditions => ['timestamp < ?', date.beginning_of_day.utc],
        :order      => 'timestamp DESC, id DESC'
      )) && row.date
    end

    # date の直後の Message がある日を返す
    def day_after(date)
      (row = first(
        :conditions => ['timestamp > ?', date.end_of_day.utc],
        :order      => 'timestamp, id'
      )) && row.date
    end
  end


  # NOTICE かどうか
  def notice?
    command == Net::IRC::Constants::NOTICE
  end

  # timestamp の date 部分
  def date
    timestamp.localtime.to_date
  end
end
