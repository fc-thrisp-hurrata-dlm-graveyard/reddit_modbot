require "modbot/version"
require "modbot/reddit_wrap"
require "modbot/modbot_fetch"
require "modbot/modbot_check"
require "modbot/modbot_score"
require "modbot/modbot_process"
require "modbot/modbot_utilities"
require "logger"

#module Modbot
#  autoload :ModbotAgent, '' 
#  autoload :ModbotFetch, ''
#  autoload :ModbotCheck, ''
#  autoload :ModbotScore, '' 
#  autoload :ModbotProcess, '' 
#  autoload :ModbotUtilities, ''
#end

module Modbot #ModbotAgent
  class Agent
    include RedditWrap
    include ModbotFetch
    include ModbotCheck
    include ModbotScore
    include ModbotProcess 
    include ModbotUtilities

    attr_accessor :moderator, :subreddits, :conditions

    QUEUES = [:report, :spam, :submission]

    def initialize(config = :pass_arg, moderator = {}, subreddits = [], conditions = [], options = {})
      initialize_internet_agent
      if config == :pass_arg
        @m_modrname = moderator['name']
        @m_password = moderator['pass']
        @subreddits = subreddits
        @conditions = conditions
        options ? @options = options : @options = {}
      elsif config == :pass_config
        mbc = YAML::load(File.open("modbot.yml")) #how to find root and where should this be or path specification        
        @m_modrname, @m_password = mbc['moderator']['name'], mbc['moderator']['pass']
        @subreddits = mbc['subreddits']
        @conditions = mbc['conditions'] 
        mbc['options'] ? @options = mbc['options'] : @options = {} 
      end
      initialize_options
      initialize_logger
      @conditions = initialize_conditions(@conditions)
      @subreddits = initialize_subreddits(@subreddits)
      login_moderator
    end

    def to_s
      "reddit_modbot for reddits #{current_subreddits_names.join(",")} (moderator: #@m_modrname)"
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

    def current_subreddits_names
      @subreddits.each.collect(&:name)
    end   

    #intialize an agent to handle the internet
    def initialize_internet_agent 
      @internet_agent = Mechanize.new{ |agent| agent.user_agent_alias = 'Mac Safari' }
      @internet_agent.history_added = Proc.new {sleep 2}
    end

    #process subreddits on intialize
    def initialize_subreddits(what_subreddits)
      z = []
      @timestamp_offset ? time = (Time.now.to_f - @timestamp_offset) : time = Time.now.to_f
      what_subreddits.each do |x|
        h = Hashie::Mash.new
        h.name, h.report_threshold, h.spam_threshold, h.submission_threshold, h.item_limit = x[0], x[1], x[2], x[3], x[4]
        h.timestamps = Hashie::Mash.new
        QUEUES.each {|q| h.timestamps["#{q}_last"] = time}
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
        h.weight = x[5].to_f || 1.to_f
        h.what = process_what(x[3])
        x[6].nil? ? h.scope = "global" : h.scope = x[6]
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

    def initialize_options
      #cull invalid options
      acceptable = [:timestamp_offset, :destructive]
      #@timestamp_offset #set an initial time for polling queues, else agent will only work from time it first fetches forward
      @options.each { |k,v| instance_variable_set("@#{k}",v)}
      @timestamp_offset ? @timestamp_offset = (@timestamp_offset * (60*60*24)) : nil
      @destructive == true||false ? @destructive = @destructive : @destructive = false 
    end

    def intialize_logger
      @l = Logger.new(STDOUT)
      @l.datetime_format = "%Y%m%d:%H%M%S"
      @l.formatter = proc do |severity, datetime, progname, msg|
        "#{datetime}: #{msg}\n"
      end

    def login_moderator
      login(m_modrname,m_password) unless ( m_modrname.nil? || m_password.nil? )
      @uh = get_current_user(m_modrname).uh
    end

    #fetch results for this agent
    #subreddits must be in an array!
    def fetch(subreddits = current_subreddits, queues = QUEUES)
      subreddits.each do |s|
        queues.each { |x| fetch_recent(x, s) } unless queues.nil?
      end
    end
 
    #check the current by q 
    def check(subreddits = current_subreddits, queues = QUEUES)
      subreddits.each do |s|
        @subreddit = s.name.to_sym
        queues.each { |x| check_results(s["#{x}_recent"]) } unless queues.nil?
      end
    end

    #score the current by q 
    def score(subreddits = current_subreddits, queues = QUEUES)
      subreddits.each do |s|
        queues.each { |x| score_results(s["#{x}_recent"]) } unless queues.nil?
      end
    end

    #process the current by q
    def process(subreddits = current_subreddits, queues = QUEUES)
      subreddits.each do |s|
        queues.each { |x| process_results(s["#{x}_recent"]) } unless queues.nil?
      end
    end

    def manage_subreddits
      fetch
      check #some sort of cascadng proceed condition if fetch yields nothing 
      score#
      process unless @destructive == false        
    end

  end
end
