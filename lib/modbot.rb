require "modbot/version"
require "modbot/reddit_wrap"
require "modbot/modbot_utilities"

module Modbot

  class ModBot
    include RedditWrap
    #include ModbotUtilities

    attr_accessor :moderator, :subreddits, :conditions

    def initialize(config = :pass_param, moderator = {},subreddits = [], conditions = [])
      @r = Mechanize.new{ |agent| agent.user_agent_alias = 'Mac Safari' }
      @r.pre_connect_hooks << Proc.new { sleep 1 }
      #good for one, but what happens with a number of instances making requests?
      #each unit would comprise a separate enitity, so as long as each plays by the api rules, then ok(ish)
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
      @r  # ||= Mechanize.new{ |agent| agent.user_agent_alias = 'Mac Safari' }
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

    #def m_pack
    #  [@m_modrname, @m_password, @uh]
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
        h.name = x[0]
        h.report_limit = x[1]
        h.spam_limit = x[2]
        h.submission_limit = x[3]
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

    def belch_out_agent
      @r.inspect
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
        #something isn't cool, pass or error 
      end
    end

    def perform_alert(item)
    end

    #reports, spam, and submissions might be abstracted to one function instead of repeating 3 similar
    #Checks reported items for any matching conditions.
    #report, spam, or submission
    #def results_fetch(subreddit, limit symbol) then pull that apart.... :spam_limit >>>> spam
    def results_fetch(which_q, subreddit, limit)
      which_to = self.method('get_reddit_' + which_q + 's')
      results = which_to.call(subreddit.name, limit)
      if results == ["Nothing!"]
        #log nothing to report
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
      which_to = subreddit.method(alert)
      if which_to.call <= count
        self.perform_alert()
        #log alert
      end
    end

    #Checks an item against a set of conditions.
    def check_conditions(item)
      conditions = current_conditions_bysubject(item.subject)
      conditions.each do |c| #unless conditions.empty? 
        check_condition(c, item)
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
        false#log action false or just pass
      end
    #log_action(condition, item)
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
    end

    #
    #def perform_regular
      #make a config item 
      #puts "check reports"
      #puts "check spam"
      #puts "check new submissions"
    #  belch_out_agent
    #end

    def timestamps_top 
      @timestamps
    end

    #see if time has changed on newest item
    #def compare_timestamps(for_what, for_when)
    #  if @timestamps.send(for_what).nil?
    #    #top time stamp is now
    #  elsif
    #  end
    #end

  end

end
