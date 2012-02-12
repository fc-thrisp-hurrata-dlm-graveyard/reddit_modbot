require "modbot/version"
require "modbot/reddit_wrap"
require "modbot/modbot_utilities"

module Modbot

  class ModBot
    include RedditWrap
    include ModbotUtilities

    attr_accessor :moderator, :subreddits, :conditions

    def initialize(config = :pass_param, moderator = {},subreddits = [], conditions = [])
      @l = Logger.new(STDOUT)
      @r = Mechanize.new{ |agent| agent.user_agent_alias = 'Mac Safari' }
      @r.post_connect_hooks << Proc.new { sleep 2 }#s
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

    def login_moderator
      self.login(m_modrname,m_password)
      x = self.get_current_user(m_modrname)
      @uh = x.uh
    end

    def perform_action(action, item)
      case action
      when :approve
        self.approve(item.fullid)
      when :remove
        self.remove(item.fullid)
      when :alert
        self.perform_alert([action.to_s, item])
      else
        @l.info "Oddly, nothing to perform but perform action triggered"
      end
    end

    def perform_alert(contents = [])
      #
    end

    #Checks for items with more reports than the subreddit's threshold.
    def check_alerts(alert, count, subreddit)
      if subreddit.send(alert) <= count
        #perform_alert -- just notify from here
        @l.info "I need to perform an alert, and I have done this"
      end
    end

    #Checks an item against a set of conditions.
    def check_conditions(item)
      conditions = current_conditions_bysubject(item.kind.to_sym)
      conditions.each do |c| #unless conditions.empty? 
        check_condition(c, item)
        @l.info "condition #{[c.subject, c.attribute, c.query, c.what, c.action]} checked"
      end
    end

    #Checks an item against a single condition.
    def check_condition(condition, item)
      case condition.attribute
      when :author
        i = item.author[0]
      when :title
        i = item.title
      when :body# should be able to take 
        i = item.body
      when :domain
        i = URI(item.url).host
      #when :url #not even close, will take some tweaking, do not use right now
      #  i = []
      #  item.url.each do |ii|
      #    ii = URI(ii)
      #    i << [ii.host, ii.path].reject { |s| s.empty? }
      #  end
      #  i.flatten
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
      @l.info "for this condition: #{i} is to be checked against #{condition.attribute}"
    end

    #Checks reported items for any matching conditions: report, spam, or submission
    def fetch_results(which_q, subreddit)
      which_to = self.method('get_reddit_' + which_q + 's')
      results = which_to.call(subreddit.name)#add way to override wrap limits 
      @l.info "results fetched #{results.count} from #{which_q}"
      results = compare_times(results, which_q)
      @l.info "only #{results.count} are new"
      if results.empty?
        @l.info "nothing to report"
      else 
        check_alerts( (which_q + '_limit').to_sym, results.count, subreddit)
        results.each do |i|
          check_conditions(i)  
        end
        @l.info "all conditions checked"
      end
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
        tt = []
        condition.what.each do |t|
          tt << Regexp.new(Regexp.escape(t))
        end
        #test = Regexp.union tt =~ test_item  # TypeError: can't convert NilClass to String
        test = Regexp.union tt
        test =~ test_item
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
      @l.info "#{test_item} tested for #{condition.query}"
    end

    #see if time has changed on newest item, filter for only items newer than last check
    def compare_times(results, which_q)
      if @timestamps.send(which_q.to_sym).nil?
        @timestamps[ (which_q +'_last')] = results[0].timestamp
        results = results
      else
        what_time = (which_q + '_last').to_sym
        time_to_check = @timestamps.send(what_time)
        results = results.select { |r| r.timestamp > time_to_check }
      end
    end

  end

end
