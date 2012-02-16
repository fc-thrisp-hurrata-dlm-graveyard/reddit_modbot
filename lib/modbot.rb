require "modbot/version"
#require "modbot/modbot"
require "modbot/reddit_wrap"
require "modbot/modbot_fetch"
require "modbot/modbot_check"
require "modbot/modbot_process"
require "modbot/modbot_utilities"
require "logger"

module Modbot
  class Agent
    #autoload perhaps 
    include RedditWrap
    include ModbotFetch
    include ModbotCheck 
    include ModbotProcess 
    include ModbotUtilities

    attr_accessor :moderator, :subreddits, :conditions

    QUEUES = [:report, :spam, :submission]

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

    def current_timestamps
      @timestamps
    end

    #start thinking about handling wrappers modularly
    def initialize_wrapper
      @api_rate_limit = 2 
    end

    #intialize an agent to handle the internet
    def initialize_internet_agent 
      @internet_agent = Mechanize.new{ |agent| agent.user_agent_alias = 'Mac Safari' }
      @internet_agent.history_added = Proc.new {sleep @api_rate_limit}
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
        h.weight = x[5] || 1
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
      login(m_modrname,m_password) unless ( m_modrname.nil? || m_password.nil? )
      @uh = get_current_user(m_modrname).uh
    end

    #fetch results for this agent
    def fetch(subreddits = current_subreddits, queues = QUEUES)
      subreddits.each do |s|
        queue.each { |x| fetch_results(x, s) } unless queue.nil?
      end
    end
 
    #check the current or passed(hmmmm, tbd) set of results for this agent 
    def check(subreddits = current_subreddits, queues = QUEUES)
      subreddits.each do |s|
        queue.each { |x| check_results(s["#{x}_recent"]) } unless queue.nil?
      end
    end

    #check the current or passed(hmmmm, tbd) set of results
    def process(subreddits = current_subreddits, queues = QUEUES)
      subreddits.each do |s|
        queue.each { |x| process_results(s["#{x}_recent"]) } unless queue.nil?
      end
    end

    def manage_subreddits
      fetch
      check
      process       
    end

  end
end
