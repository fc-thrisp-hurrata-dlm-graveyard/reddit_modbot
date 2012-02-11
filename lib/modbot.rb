require "modbot/version"
require "modbot/reddit_wrap"
require "modbot/modbot_utilities"

module Modbot

  class ModBot
    include RedditWrap
    #include ModbotUtilities

    attr_accessor :moderator, :subreddits, :conditions

    def initialize(config = :pass_param, moderator = {},subreddits = [], conditions = [])
      @l = Logger.new(STDOUT)
      @r = Mechanize.new{ |agent| agent.user_agent_alias = 'Mac Safari' }
      @r.pre_connect_hooks << Proc.new { sleep 2 }
      if config == :pass_param
        @m_modrname = moderator['name']
        @m_password = moderator['pass']
        @subreddits = subreddits
        @conditions = conditions
      elsif config == :config_file
        mbc = YAML::load(File.open("modbot.yml")) #how to find root and where should this be or path specification        
        @m_modrname, @m_password = mbc['moderator']['name'], mbc['moderator']['pass']
        @subreddits = mbc['subreddits']
        @conditions = mbc['conditions']
      end
      @timestamps = Hashie::Mash.new
      login_moderator
    end

    def internet_agent
      @r
    end

    def m_modrname
      @m_modrname
    end

    def m_password
      @m_password
    end
 
    def m_uh
      @uh
    end

    def timestamps_top 
      @timestamps
    end

    #def m_pack
    #  [@m_modrname, @m_password, @uh]
    #end

    #def belch_out_agent
    #  @r.inspect
    #end

    def login_moderator
      self.login(m_modrname,m_password)
      x = self.get_current_user(m_modrname)
      @uh = x.uh
    end

    def current_subreddits
      z = []
      self.subreddits.each do |x|
        h = Hashie::Mash.new
        h.name, h.report_limit, h.spam_limit, h.submission_limit = x[0], x[1], x[2], x[3]
        z << h
      end
      z
    end

    def current_conditions
      z = []
      conditions.each do |x|
        h = Hashie::Mash.new
        h.subject, h.attribute, h.query, h.what, h.action = x[0].to_sym, x[1].to_sym, x[2].to_sym, x[3], x[4].to_sym
        z << h
      end
      z
    end

    def current_conditions_bysubject(subject)
      current_conditions.select { |x| x.subject == subject } 
    end

    def perform_action(action, item)
      case action
      when :approve
        self.approve(item.fullid)
      when :remove
        self.remove(item.fullid)
      when :alert
        self.perform_alert()
      else
        @l.info('nothing to perform') 
      end
    end

    def perform_alert(item)
      @l.info('alert triggered')
    end

    #Checks reported items for any matching conditions.
    #report, spam, or submission
    def results_fetch(which_q, subreddit, limit)
      which_to = self.method('get_reddit_' + which_q + 's')
      results = which_to.call(subreddit.name, limit)
      if results
        @l.info('results fetched')
      end
      results = compare_times(results, which_q)
      if results.empty?
        @l.info('nothing to report')
      else 
        check_alerts( (which_q + '_limit').to_sym, results.count, subreddit)
        results.each do |i|
          check_conditions(i)  
        end
        #log end conditions check
      end
    end

    #Checks for items with more reports than the subreddit's threshold.
    def check_alerts(alert, count, subreddit)
      if subreddit.send(alert) <= count
        perform_alert()
        @l.info('check_alerts')
      end
    end

    #Checks an item against a set of conditions.
    def check_conditions(item)
      conditions = current_conditions_bysubject(item.subject)
      conditions.each do |c| #unless conditions.empty? 
        check_condition(c, item)
        @l.info('condition checked')
      end
    end

    #Checks an item against a single condition.
    def check_condition(condition, item)
      case condition.attribute
      when :author
        i = item.author[0]
      when :title
        i = item.title
      when :body
        i = item.body
      when :domain
        i = URI(item.url).host
      when :url
        i = URI(item.url)
      when :self_post
        i = item.is_self
      when :min_account_age
        i = item.author[2]
      when :min_link_karma
        i = item.author[3]
      when :min_comment_karma
        i = item.author[4]
      when :min_combined_karma
        i = (item.author[3] + item.author[4])
      end
      result = test_condition(i, condition)
      if result
        perform_action(condition.action, item)
      else
        #log action false or just pass
      end
      @l.info('condition checked')
    end
  
    #tests an item against a condition, returns true or false
    def test_condition(test_item, condition)
      case condition.query 
      when :matches
        test = Regexp.union(condition.what) =~ test_item
        if test.nil?
          false
        else
          true
        end
      when :contains
        test = Regexp.union( (condition.what).split ) =~ test_item
        if test.nil?
          false
        else
          true
        end
      when :is_greater_than
        test_item > condition.what
      when :is_less_than
        test_item < condition.what
      else
        false 
      end
      @l.info('item tested')
    end

    #see if time has changed on newest item, filter for only items newer than last check
    def compare_times(results, which_q)
      if @timestamps.send(which_q.to_sym).nil?
        @timestamps[ (which_q +'_last')] = results[0].timestamp
        results = results
      else
        what_time = (which_q + '_last').to_sym
        time_to_check = @timestamps.send(what_time)
        results.select { |r| r.timestamp > time_to_check }
      end
    end

  end

end
