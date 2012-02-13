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

    def initialize(config = :pass_arg, moderator = {}, subreddits = [], conditions = [])
      @l = Logger.new(STDOUT)
      @r = Mechanize.new{ |agent| agent.user_agent_alias = 'Mac Safari' }
      #@r.post_connect_hooks << Proc.new { sleep 2 }
      @r.history_added = Proc.new {sleep 2}
      if config == :pass_arg
        @m_modrname = moderator['name']
        @m_password = moderator['pass']
        @subreddits = subreddits
        @conditions = conditions
      elsif config == :pass_config
        mbc = YAML::load(File.open("modbot.yml")) #how to find root and where should this be or path specification        
        @m_modrname, @m_password = mbc['moderator']['name'], mbc['moderator']['pass']
        @subreddits = mbc['subreddits']
        @conditions = mbc['conditions']
      end
      @conditions = process_conditions(@conditions)
      @subreddits = process_subreddits(@subreddits)
      @timestamps = Hashie::Mash.new
      login_moderator
    end

    def to_s
      "reddit_modbot instance for moderator #{m_modrname}"
    end

    def login_moderator
      self.login(m_modrname,m_password)
      @uh = self.get_current_user(m_modrname).uh
    end

    #Checks reported items for any matching conditions: report, spam, or submission
    def fetch_results(which_q, subreddit, limit)
      which_to = self.method("get_reddit_#{which_q}s")
      results = which_to.call(subreddit.name, limit) 
      @l.info "results fetched #{results.count} from #{which_q}"
      results = compare_times(results, which_q)
      if results.empty?
        @l.info "nothing to report, #{which_q} is empty"
        subreddit["#{which_q}_recent"] = [] #stopped working for some reason
      else
        @l.info "#{results.count} new items from #{which_q} to check"
        check_alerts("#{which_q}_limit".to_sym, results.count, subreddit)
        subreddit["#{which_q}_recent"] = results#stopped working for some reason, outside of loop
      end
    end

    #see if time has changed on newest item, filter for only items newer than last check
    def compare_times(results, which_q)
      if @timestamps.send(which_q.to_sym).nil?
        @l.info "this is the most recent set of results for #{which_q}"
        if results.empty?
           @timestamps["#{which_q}_last"] = Time.now.to_f.round(3)
        else
           @timestamps["#{which_q}_last"] = results[0].timestamp
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
      conditions = relevant_conditions(item.kind.to_sym)
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
      when :body
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
      @l.info "#{i} to be checked against #{condition.attribute}"
      test_condition(condition, item, i)
    end
             
    #tests an item against a condition, returns true or false
    def test_condition(condition, item, test_item)
      case condition.query 
      when :matches || :contains
        test = condition.what =~ test_item
      when :is_greater_than
        test = test_item > condition.what
      when :is_less_than
        test = test_item < condition.what
      end
      if test.kind_of?(Integer) || test == true
        item.verdict << condition.action
        test_result = true
      elsif test.nil? || test == false
        item.verdict << :fail
        test_result = false 
      else
        test_result = "failure"
      end
      @l.info "#{test_item} ::: #{condition.query} #{condition.what} ::: #{test_result}"
    end

    def process_results(results_set)
      results_set.each do |v|
        if v.verdict.empty?
          @l.info "Not enough information to make a decision on this item"
        else
          verdict = v.verdict.count {|x| x == :approve }.to_f / v.verdict.count {|x| x == :remove }.to_f
          if verdict.infinite?
            verdict = 1
            action = v.action
          elsif verdict.nan?
            verdict = 0
            action = :inconclusive
          else
            verdict >= 1 ? action = :approve : action = :remove
          end
          v.score = verdict
          perform_action(action, v)
        end
      end
    end

    def perform_action(action, item)
      case action
      when :inconclusive
        @l.info "not enough data to remove or approve this item"
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
    def manage_subreddit(subreddit, fw, limit)
      fw.map{ |f| self.fetch_results(f, subreddit, limit) }
      fw.map{ |f| self.check_results(subreddit["#{f}_recent"]) }
      fw.map{ |f| self.process_results(subreddit["#{f}_recent"]) } 
    end

    def manage_subreddits(for_what, limit)#["spam", "report", "submission"] or any combo of
      
      current_subreddits.each do |s|
        manage_subreddit(s, for_what, limit)
      end

      #@l.info "fetched results #{fw} for #{s.name}" 
      #@l.info "checked results #{s.name} #{fw}_recent"
      #@l.info "processed results #{s.name} #{fw}_recent"
        
    end

  end
end
