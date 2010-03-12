module ApplicationHelper
  def link_to_date(name, date)
    date.nil? ? name :
      link_to(name,
        :controller => 'messages',
        :action     => 'index',
        :date       => build_date_param(date)
      )
  end

  # channel ページへのリンク
  def link_to_channel(name, channel, date = :blank)
    date.nil? ? name :
      link_to(name,
        :controller => 'messages',
        :action     => 'channels',
        :channel    => channel.name,
        :week       => build_week_param(date)
      )
  end

  # user ページへのリンク
  def link_to_user(name, user, date = :blank)
    date.nil? ? name :
      link_to(name,
        :controller => 'messages',
        :action     => 'users',
        :user       => user.name,
        :week       => build_week_param(date)
      )
  end

  private
    # date ページの date パラメータを返す
    def build_date_param(date)
      date.strftime('%Y%m%d')
    end

    # channel/user ページの date パラメータを返す
    def build_week_param(date)
      date == :blank ? nil : date.strftime('%G%V')
    end
end
