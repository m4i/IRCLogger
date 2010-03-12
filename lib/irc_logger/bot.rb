require 'logger'
require 'net/irc'
require 'net/irc/client/channel_manager'

Thread.abort_on_exception = true

module IRCLogger
  module Bot
    # 出力されるログのパス
    LOG_PATH = File.join(RAILS_ROOT, 'log', "bot.#{RAILS_ENV}.log")

    # サーバへの再接続の秒数
    CONNECT_INTERVAL = 60

    def run
      logger = OriginalLogger.new(LOG_PATH)
      #logger = OriginalLogger.new($stdout)

      begin
        # 出力されるログを加工
        def logger.debug(progname = nil, &block)
          progname ||= @progname
          if block_given?
            message = yield
          else
            message  = progname
            progname = @progname
          end

          case message
          # パスワードがログに残らないように
          when /\ASEND: PASS /
            message = $& + '*' * 16
          # ログが増えすぎないように出力しない
          when /\ARECEIVE: :[-.\w]+ #{Net::IRC::Constants::RPL_LIST} /
            return true
          end

          add(Logger::DEBUG, message, progname)
        end

        opts = IRCLogger.config.bot.marshal_dump.dup
        opts.update(:logger => logger)
        host = opts.delete(:host)
        port = opts.delete(:port)

        loop do
          begin
            Client.new(host, port, opts).start
          rescue Errno::ECONNREFUSED
            logger.error inspect_exception($!)
          end
          sleep CONNECT_INTERVAL
        end
      rescue Exception
        logger.fatal inspect_exception($!)
      end
    end
    module_function :run

    def inspect_exception(exception)
      ([exception] + exception.backtrace).join("\n  ")
    end
    module_function :inspect_exception


    class OriginalLogger < ::Logger
      if private_method_defined?(:old_format_message)
        alias format_message old_format_message
      end
    end


    class Client < Net::IRC::Client
      include Net::IRC::Client::ChannelManager

      DEFAULT_MODES    = { :+ => [:n], :- => [:t] }
      IGNORE_CHANNELS  = %w( #ngircd )

      def initialize(*args)
        super
        @nick      = @opts.nick
        @user      = @opts.user
        @connected = false
        @rejoin    = {}
        @threads   = []
      end

      # 接続が切れたとき
      def finish
        @threads.each(&:exit)
        @threads = []
        @connected = false
        super
      end

      # ログイン直後
      def on_rpl_endofmotd(m)
        super
        unless @connected
          @connected = true
          join_known_channels
          start_listing
          start_posting
        end
      end

      # LIST コマンドの結果を受け取ったとき
      def on_rpl_list(m)
        super
        channel = m[1]
        unless IGNORE_CHANNELS.include?(channel)
          join channel
        end
      end

      # nick が重複したとき
      def on_err_nicknameinuse(m)
        super
        post NICK, new_nick
      end

      # 招待されたらすぐ join
      def on_invite(m)
        super
        join m[1]
      end

      # PRIVMSG を受け取ったとき
      def on_privmsg(m)
        super
        on_recieve_message(m)
      end

      # NOTICE を受け取ったとき
      def on_notice(m)
        super
        on_recieve_message(m)
      end

      # 誰かが退室したとき
      def on_part(m)
        super
        channel = m[0]

        # bot 自身が part した場合
        if m.prefix.nick == @nick
          @channels.delete(channel)
          if @rejoin.delete(channel)
            join channel
          end

        # 他人が part した場合
        else
          on_decrement_user(m, channel => @channels[channel])
        end
      end

      # 誰かが切断したとき
      def on_quit(m)
        super
        on_decrement_user(m)
      end

      # 誰かが kick されたとき
      def on_kick(m)
        super
        channels = m[0].split(/,/)
        users    = m[1].split(/,/)

        # kick されたときはその channel 情報を削除する
        if users.include?(@nick)
          channels.each do |channel|
            @channels.delete(channel)
          end
        end
      end

      # join が成功したとき
      def on_rpl_namreply(m)
        super
        channel_name = m[2]

        # bot へのトークでなければ
        unless @nick == channel_name
          channel = ::Channel.find_or_create!(channel_name)

          # op なら mode を設定
          if op?(channel.name)
            set_mode channel.name, DEFAULT_MODES
          end

          # topic を設定しようと試みる
          set_topic channel.name, channel.topic if channel.topic
        end
      end

      # 誰かが topic を設定したとき
      def on_topic(m)
        channel = m[0]
        topic   = m[1]
        ::Channel.find_or_create!(channel).update_topic!(topic)
      end

      # join 直後の topic の通知
      def on_rpl_topic(m)
        channel = m[1]
        topic   = m[2]
        ::Channel.find_or_create!(channel).update_topic!(topic)
      end

      private
        # 既知の channel に join する
        def join_known_channels
          ::Channel.names.each do |channel|
            join channel
          end
        end

        # LIST を送信し始めるまでの秒数
        LISTING_WAIT = 10

        # LIST を送信する間隔
        LISTING_INTERVAL = 30

        # 定期的に LIST コマンドを送る
        def start_listing
          @threads << Thread.start do
            sleep LISTING_WAIT
            loop do
              begin
                post LIST
              rescue
                log_error($!)
              end
              sleep LISTING_INTERVAL
            end
          end
        end

        # posts を監視し始めるまでの秒数
        POSTING_WAIT = 30

        # posts を検索しにいく間隔
        POSTING_INTERVAL = 10

        # posts テーブルを定期的に監視する
        def start_posting
          @threads << Thread.start do
            sleep POSTING_WAIT
            loop do
              begin
                ::Post.unposted.each do |post|
                  post_by_post(post)
                  sleep 5
                end
              rescue
                log_error($!)
              end
              sleep POSTING_INTERVAL
            end
          end
        end

        # posts テーブルのレコードを処理する
        def post_by_post(post)
          join post.channel.name
          post post.command, post.channel.name, post.message

          post.transaction do
            post.posted!
            create_message(
              :channel   => post.channel.name,
              :command   => post.command,
              :user      => @user,
              :nickname  => @nick,
              :message   => post.message
            ) || raise(ActiveRecord::RecordNotSaved)
          end

        rescue ActiveRecord::RecordNotSaved, ActiveRecord::RecordInvalid
          log_error($!)
        end

        # user 名から "~" を削除
        def normalize_user(user)
          user.sub(/^~/, '')
        end

        # 現在の nick の末尾に "_" を付ける
        def new_nick
          @nick += '_'
        end

        # channel で nick の人が op かどうかを返す
        def op?(channel, nick = @nick)
          if (info = @channels[channel]) && (modes = info[:modes])
            modes.each do |mode, value|
              if mode == :o && value == nick
                return true
              end
            end
          end
          return false
        end

        # join していない channel であれば join する
        def join(channel)
          unless @channels[channel]
            post JOIN, channel
          end
        end

        # join している channel であれば part する
        def part(channel)
          if @channels[channel]
            post PART, channel
          end
        end

        # mode をセットする
        def set_mode(channel, modes)
          mode = ''
          mode << '+' + modes[:+].map(&:to_s).join unless modes[:+].empty?
          mode << '-' + modes[:-].map(&:to_s).join unless modes[:-].empty?
          post MODE, channel, mode unless mode.empty?
        end

        # topic をセットする
        def set_topic(channel, topic)
          post TOPIC, channel, topic
        end

        # PRIVMSG, NOTICE を受け取ったときに呼び出される
        def on_recieve_message(m)
          return unless m.prefix.user

          channel = m[0]

          # bot へのトークの場合
          if @nick == channel
            case m[1]
            when /^(#\S+) (\+o) (\S+)$/ # operation を要求
              post MODE, *$~.captures
            end

          # channel への発言の場合
          else
            create_message(
              :channel   => m[0],
              :command   => m.command,
              :user      => normalize_user(m.prefix.user),
              :nickname  => m.prefix.nick,
              :message   => m[1]
            )
          end
        end

        # 人数が減ったときに最後の一人であれば join しなおす
        def on_decrement_user(m, channels = @channels)
          channels.each do |channel, info|
            if info[:users].length == 1
              @rejoin[channel] = true
              part channel
            end
          end
        end

        # message を database に保存する
        def create_message(data)
          unless ([:channel, :command, :user, :nickname, :message] - data.keys).length.zero?
            raise Exception, 'must not happen'
          end

          ::Message.transaction do
            ::Message.create!({
                :channel_id => ::Channel.find_or_create!(data.delete(:channel)).id,
                :user_id    => ::User.find_or_create!(data.delete(:user)).id,
                :timestamp  => Time.now,
            }.merge(data))
          end

        rescue ActiveRecord::RecordNotSaved, ActiveRecord::RecordInvalid
          log_error($!)
          false
        end

        # 例外をログに記録する
        def log_error(exception)
          @log.error Bot.inspect_exception(exception)
        end
    end
  end
end
