require "modbot/version"
require "modbot/reddit_wrap"
require "modbot/modbot_fetch"
require "modbot/modbot_check"
require "modbot/modbot_process"
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
    include ModbotFetch
    include ModbotCheck 
    include ModbotProcess 
    include ModbotUtilities

    attr_accessor :moderator, :subreddits, :conditions

    def initialize(config = :pass_arg, moderator = {}, subreddits = [], conditions = [])
      @l = Logger.new(STDOUT)
      initialize_internet_agent
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
      @conditions = initialize_conditions(@conditions)
      @subreddits = initialize_subreddits(@subreddits)
      @timestamps = Hashie::Mash.new
      @l.info "#{self.to_s} intialized with #{@conditions} for #{@subreddits}"
      login_moderator
    end

    def to_s
      "reddit_modbot instance for moderator #@m_modrname"
    end

    def internet_agent
      @internet_agent
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

    def current_conditions
      @conditions
    end

    def current_subreddits
      @subreddits
    end

    def timestamps_top 
      @timestamps
    end

    def initialize_internet_agent 
      @internet_agent = Mechanize.new{ |agent| agent.user_agent_alias = 'Mac Safari' }
      @internet_agent.history_added = Proc.new {sleep 2}
    end

    #process subreddits on intialize
    def initialize_subreddits(what_subreddits)
      z = []
      what_subreddits.each do |x|
        h = Hashie::Mash.new
        h.name, h.report_threshold, h.spam_threshold, h.submission_threshold, h.item_limit = x[0], x[1], x[2], x[3], x[4]
        z << h
      end
      z
    end

    #process conditions on intialize
    def initialize_conditions(what_conditions)
      z = []
      what_conditions.each do |x|
        h = Hashie::Mash.new
        h.subject, h.attribute, h.query, h.action = x[0].to_sym, x[1].to_sym, x[2].to_sym, x[4].to_sym
        h.what = process_what(x[3])
        case h.query
        when :matches
          h.what = Regexp.union(h.what)
        when :contains
          tt = []
          h.what.each do |t|
            tt << Regexp.new(Regexp.escape(t))
          end
          h.what = Regexp.union tt
        end
        z << h
      end
      z
    end

    def login_moderator
      login(m_modrname,m_password)
      @uh = get_current_user(m_modrname).uh
    end

    #make less clumsy
    def manage_subreddit(for_what, subreddit)
      for_what.each { |f| self.fetch_results(f, subreddit) }
      for_what { |f| self.check_results(subreddit["#{f}_recent"]) }
      for_what { |f| self.process_results(subreddit["#{f}_recent"]) } 
    end

    def manage_subreddits(for_what)#[:spam, :report, :submission] or any combo of
      current_subreddits.each { |s| manage_subreddit(for_what, s) }        
    end

  end
end
