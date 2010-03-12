class MessagesController < ApplicationController
  # 正しい param[:date] の正規表現
  DATE_PARAM_REGEX = /(20[01]\d)(0[1-9]|1[0-2])(0[1-9]|[12]\d|3[01])/

  # 正しい param[:week] の正規表現
  WEEK_PARAM_REGEX = /(20[01]\d)(0[1-9]|[1-4]\d|5[0-3])/

  # 検索結果ページでの最大表示件数
  SEARCH_LIMIT = 1000

  def index
    scope          = Message.without_bot
    @date          = get_date(scope)
    @previous_date = scope.day_before(@date)
    @next_date     = scope.day_after(@date)
    @messages      = scope.find_all_by_period(@date)
  end

  def channels
    @channel = Channel.find_by_name(params[:channel])
    redirect_to :action => index unless @channel

    scope          = Message.by_channel(@channel)
    @from_date     = get_date_by_week(scope)
    @to_date       = @from_date.end_of_week
    @previous_date = scope.day_before(@from_date)
    @next_date     = scope.day_after(@to_date)
    @messages      = scope.find_all_by_period(@from_date, @to_date)

    @search_extra = "channel:#{@channel.name}"
  end

  def users
    @user = User.find_by_name(params[:user])
    redirect_to :action => index unless @user

    scope          = Message.by_user(@user)
    @from_date     = get_date_by_week(scope)
    @to_date       = @from_date.end_of_week
    @previous_date = scope.day_before(@from_date)
    @next_date     = scope.day_after(@to_date)
    @messages      = scope.find_all_by_period(@from_date, @to_date)

    @search_extra = "user:#{@user.name}"
  end

  def search
    # 2回エスケープしないと Passenger で動作しない
    @search = CGI.unescape(CGI.unescape(request.request_uri.sub(%r|^/search/|, '')))
    conditions = parse_search(@search)

    @messages = Message.all(
      :include    => [:channel, :user],
      :conditions => conditions,
      :order      => 'messages.timestamp DESC, messages.id DESC',
      :limit      => SEARCH_LIMIT
    ).reverse
  end

  private
    # 日が指定された場合はその日を返し
    # 指定されなかった場合は最新の Message の日を返す
    def get_date(scope = Message)
      if params[:date] =~ /\A#{DATE_PARAM_REGEX}\z/ &&
         jd = Date.valid_date?($1.to_i, $2.to_i, $3.to_i)
        @date_by_param = true
        Date.jd(jd)
      else
        message = scope.first(:order => 'timestamp DESC, id DESC')
        message ? message.date : Date.today
      end
    end

    # 週が指定された場合はその週の月曜日を返し
    # 指定されなかった場合は最新の Message の週の月曜日を返す
    def get_date_by_week(scope = Message)
      if params[:week] =~ /\A#{WEEK_PARAM_REGEX}\z/ &&
         jd = Date.valid_commercial?($1.to_i, $2.to_i, 1)
        @date_by_param = true
        Date.jd(jd)
      else
        message = scope.first(:order => 'timestamp DESC, id DESC')
        (message ? message.date : Date.today).beginning_of_week
      end
    end

    # 検索文字列を分析し find に渡す conditions を返す
    #
    # ==== TODO
    # * phrase 検索の -
    # * OR 検索
    def parse_search(string)
      words, phrases   = split_into_words(string)
      conditions_array = make_conditions_array(words, phrases)
      build_conditions(conditions_array)
    end

    def split_into_words(string)
      words   = []
      phrases = []

      string.scan(/([^"]*)(?:"([^"]*)(?:"([^"]*))?)?/) do |pre_words, phrase, post_words|
        words.concat pre_words.split(/[\s　]+/)
        phrases <<   phrase                      if phrase
        words.concat post_words.split(/[\s　]+/) if post_words
      end

      words.delete_if {|w| w =~ /^[\s　]*$/ }

      [words, phrases]
    end

    def make_conditions_array(words, phrases)
      conditions_array = []

      words.each do |word|
        case word
        when /^(-)?(channel|user|nickname):/
          exception = $1 ? true : false
          type      = $2.to_sym
          word      = $'
        when /^(-)?/
          exception = $1 ? true : false
          type      = :message
          word      = $'
        end
        conditions_array << [exception, type, word]
      end

      conditions_array.concat(phrases.map {|p| [false, :message, p] })
    end

    def build_conditions(conditions_array)
      wheres = []
      values = []

      conditions_array.each do |exception, type, value|
        where, value = case type
          when :message
            ['messages.message %sLIKE ?' % (exception ? 'NOT ' : ''), "%#{value}%"]
          when :channel
            ['channels.name %s= ?' % (exception ? '!' : ''), value]
          when :user
            ['users.name %s= ?' % (exception ? '!' : ''), value]
          else
            ["messages.%s %s= ?" % [type, exception ? '!' : ''], value]
          end

        wheres << where
        values << value
      end

      [wheres.join(' AND '), *values]
    end
end
