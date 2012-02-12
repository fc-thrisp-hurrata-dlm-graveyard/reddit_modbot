require "modbot/version"
require "modbot/reddit_wrap"
require "modbot/modbot_utilities"

module Modbot

  class ModBot

    #main(fetch       -- results,
    #     compare     -- times,
    #     check       -- items/conditions,
    #     test        -- item what / condition attribute,
    #     process     -- check item verdicts
    #     perform     -- approve/remove/alert moderator )

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

    #Checks reported items for any matching conditions: report, spam, or submission
    def fetch_results(which_q, subreddit)
      which_to = self.method('get_reddit_' + which_q + 's')
      results = which_to.call(subreddit.name)#add way to override wrap limits 
      @l.info "results fetched #{results.count} from #{which_q}"
      results = compare_times(results, which_q)
      if results.empty?
        @l.info "nothing to report, #{which_q} is empty"
      else
        @l.info "#{results.count} new items from #{which_q} to check"
        check_alerts( (which_q + '_limit').to_sym, results.count, subreddit)
      end
      subreddit[(which_q + '_recent')] = results
    end

    #see if time has changed on newest item, filter for only items newer than last check
    def compare_times(results, which_q)
      if @timestamps.send(which_q.to_sym).nil?
        @l.info "this is the most recent set of results for #{which_q}"
        if results.empty?
           @timestamps[(which_q +'_last')] = Time.now.to_f.round(3)
        else
           @timestamps[(which_q +'_last')] = results[0].timestamp
        end 
        results = results
      else
        what_time = (which_q + '_last').to_sym
        time_to_check = @timestamps.send(what_time)
        results = results.select { |r| r.timestamp > time_to_check }
        @timestamps[(which_q +'_last')] = results[0].timestamp
        @l.info "#{which_q} results filtered against most recent time of check, new timestamp #{results[0].timestamp}"
      end
      results
    end

    #Checks for items with more reports than the subreddit's threshold.
    def check_alerts(subreddit_alert, results_count, subreddit)
      if subreddit.send(subreddit_alert) <= results_count
        #perform_alert
        @l.info "alert : #{results_count} exceed #{subreddit.send(subreddit_alert)} items for #{subreddit.name}"
      end
    end

    #Check a results set
    def check_results(results_set)
      results_set.each do |i|
        check_conditions(i)  
      end
      @l.info "all conditions checked from this result set"
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
        item.verdict << condition.action
      else
        #log action false or just pass
      end
      @l.info "#{i} to be checked against #{condition.attribute}"
    end
             
    #tests an item against a condition, returns true or false
    def test_condition(test_item, condition)
      case condition.query 
      when :matches
        test = Regexp.union(condition.what)#move up into condition processing, i.e. do once instead of each time
        test =~ test_item
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

    def process_results(results_set)
      results_set.each do |v|
        if verdict.empty?
        else
          verdict = v.verdict {|x| x == :approve }.to_f / v.verdict {|x| x == :remove }.to_f
          verdict >= 1 ? action = :approve : action = :remove
          v.score = verdict
          perform_action(action, v)
        end
      end
    end

    def perform_action(action, item)
      case action
      when :approve
        self.approve(item.fullid)
        @l.info "approved #{item.fullid}" # better description needed
      when :remove
        self.remove(item.fullid)
        @l.info "removed #{item.fullid}" # better description needed
      when :alert
        self.perform_alert([action.to_s, item])
      else
        @l.info "Oddly, nothing to perform but perform action triggered"
      end
    end

    def perform_alert(contents = [])
    end
   
    #make less clumsy
    def check_subreddit(for_what)#["spam", "report", "submission"] or any combo of
      
      current_subreddits.each do |s|
        for_what.each do |fw|
          #fetch_results(fw, s)
          @l.info "fetched results #{fw} for #{s.name}" 
          #check_results(s[(fw + '_recent')]
          @l.info "checked results #{s.name} #{fw}_recent"
          #process_results(s[(fw + '_recent')]
          @l.info "processed results #{s.name} #{fw}_recent"
        end
      end
        
    end

  end
end
