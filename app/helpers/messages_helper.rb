module MessagesHelper
  # 日付を表示用にフォーマットする
  def format_date(date)
    html_escape(date.strftime('%Y-%m-%d %a'))
  end

  # 時刻を表示用にフォーマットする
  def format_time(timestamp)
    html_escape(timestamp.localtime.strftime('%H:%M:%S'))
  end

  # 期間を表示用にフォーマットする
  def format_period(from_date, to_date)
    "#{format_date(from_date)} - #{format_date(to_date)}"
  end

  # message を表示用にフォーマットする
  def format_message(message)
    message = html_escape(message)
    message.
      gsub(%r"(?:https?|ftp)://[-\dA-Za-z]+(\.[-\dA-Za-z]+)*(?::\d+)?(?:/[!#-'*-;=?-Z_a-z~]*)?", '<a href="\&" target="_blank">\&</a>').
      gsub(/\\\\[-.\w]+\\\S+/) { m = $&; %|<a href="file://#{m.gsub('\\', '/')}">#{m}</a>| }.
      gsub(/\t/, ' ' * 4).gsub(/((?:\G|>)[^<]*?) /, '\1&nbsp;')
  end

  # tr のスタイルのための class の数
  NUMBER_OF_ROW_CLASS = 12

  # tr のスタイルのための class
  def row_class(message)
    @channel_indexes ||= {}
    @channel_index   ||= -1
    @user_indexes    ||= {}
    @user_index      ||= -1

    'channel_%02d_%s user_%02d' % [
      @channel_indexes[message.channel_id] ||= (@channel_index += 1) % NUMBER_OF_ROW_CLASS,
      cycle('odd', 'even'),
      @user_indexes[message.user_id] ||= (@user_index += 1) % NUMBER_OF_ROW_CLASS,
    ]
  end

  # 指定した message のある channel ページへのリンク
  def link_to_channel_of(message)
    link_to h(message.channel.name),
      :action  => 'channels',
      :channel => message.channel.name,
      :week    => build_week_param(message.date),
      :anchor  => message.id
  end

  # 指定した message のある user ページへのリンク
  def link_to_user_of(message)
    link_to h(message.nickname),
      :action => 'users',
      :user   => message.user.name,
      :week   => build_week_param(message.date),
      :anchor => message.id
  end
end
