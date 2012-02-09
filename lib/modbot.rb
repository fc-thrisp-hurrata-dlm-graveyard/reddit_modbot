require "modbot/version"
require "modbot/reddit_wrap"
require "modbot/modbot_utilities"

module Modbot

  class ModBot
    include RedditWrap
    #include ModbotUtilities

    attr_accessor :moderator, :subreddits, :conditions

    def initialize(config, moderator = {},subreddits = [], conditions = [])
      @r = Mechanize.new{ |agent| agent.user_agent_alias = 'Mac Safari' }
      if config == "pass_param"
        @m_modrname = moderator['name']
        @m_password = moderator['pass']
        @subreddits = subreddits
        @conditions = conditions
      elsif config == "config_file"
        mbc = YAML::load(File.open("modbot.yml")) #how to find root and where should this be or path specification        
        @m_modrname = mbc['moderator']['name']
        @m_password = mbc['moderator']['pass']
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

    def login_moderator
      self.login(m_modrname,m_password) 
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

    #Checks reported items for any matching conditions.
    def check_reports(subreddit)
      reports = get_reddit_reports(subreddit)
      check_alerts(subreddit, "report", reports.count)
      reports.each do |i|
        check_conditions(i)  
      end
    end

    #Checks new items on the /about/spam page for any matching conditions.
    def check_new_spam(subreddit, conditions)
      #compare time of first instance to recorded time of last check 
      #spams = get_reddit_spams(subreddit)
      #check_report_alerts(subreddit, "spam", spams.count)
      #spams.each do |sp|
      #  check_conditions(conditions, sp)
      #end
    end

    #Checks for items with more reports than the subreddit's threshold.
    def check_alerts(subreddit, alert, count)
      case alert
      when "report"
        if subreddit.report_limit <= count
          self.perform_alert()
        end
      when "spam"
        if subreddit.spam_limit <= count
          self.perform_alert()
        end
      when "submissions"
        if subreddit.submission_limit <= count
          self.perform_alert()
        end
      else
      end
    end

    #Checks new items on the /new page for any matching conditions.
    #def check_new_submissions(name)
    #end

    #Checks an item against a set of conditions.
    #Returns True if a condition matches, or False if none match.
    #action_types restricts checked conditions to particular action(s).
    #Setting perform to False will check, but not actually perform if matched.
    def check_conditions(item)
      conditions = current_conditions_bysubject(item.subject)
      conditions.each do |c| #unless conditions.empty? 
        check_condition(c, item)
      end
    end

    #Checks an item against a single condition (and sub-conditions).
    #Returns the condition's ID if it matches.
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

    def perform_regular
      #puts "check reports"
      #puts "check spam"
      #puts "check new submissions"
      belch_out_agent
    end

    def timestamps_top 
      @timestamps
    end

    #see if time has changed on newest item
    #def compare_time(for_what, for_when)
    #  if @timestamps.send(for_what).nil?
    #    #top time stamp is now
    #  elsif
    #  end
    #end

  end

end
