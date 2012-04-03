require "modbot/version"
require "modbot/reddit_wrap"
require "modbot/modbot_fetch"
require "modbot/modbot_check"
require "modbot/modbot_score"
require "modbot/modbot_process"
require "modbot/modbot_alerts"
require "modbot/modbot_utilities"
require "logger"

module Modbot
  class Agent
    include RedditWrap
    include ModbotFetch
    include ModbotCheck
    include ModbotScore
    include ModbotProcess
    include ModbotShadow
    include ModbotAlerts
    include ModbotUtilities
 
    attr_accessor :moderator, :subreddits, :conditions
    attr_reader :internet_agent, :m_modrname, :m_password, :current_options

    QUEUES = [:report, :spam, :submission]
 
    def initialize(config = :pass_arg, moderator = {},
                                       subreddits = [],
                                       conditions = [],
                                       custom_logger = STDOUT, 
                                       options = {})
      initialize_internet_agent
      if config == :pass_arg
        @m_modrname = moderator['name']
        @m_password = moderator['pass']
        @subreddits = subreddits
        @conditions = conditions
      elsif config == :pass_config
        mbc = YAML::load(File.open("modbot.yml"))        
        @m_modrname, @m_password = mbc['moderator']['name'], mbc['moderator']['pass']
        @subreddits = mbc['subreddits']
        @conditions = mbc['conditions'] 
        mbc['options'] ? options = mbc['options'] : options = {} 
      end
      initialize_options(options)
      initialize_logger(custom_logger)
      @conditions = initialize_conditions(@conditions)
      @subreddits = initialize_subreddits(@subreddits)
      login_moderator
    end

    def to_s
      "reddit_modbot for reddits #{current_subreddits_names.join(",")} (moderator: #@m_modrname)"
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

    # Intialize an agent to handle the internet to and fro
    def initialize_internet_agent 
      @internet_agent = Mechanize.new{ |agent| agent.user_agent_alias = 'reddit_modbot' }
      @internet_agent.history_added = Proc.new {sleep 3}
    end

    # Process subreddits into useful hashie/mash on intialize
    def initialize_subreddits(what_subreddits)
      z = []
      time = Time.now.to_f - self.timestamp_offset
      what_subreddits.each do |x|
        h = Hashie::Mash.new
        h.name, h.report_threshold, h.spam_threshold, h.submission_threshold, h.item_limit = x[0], x[1], x[2], x[3], x[4]
        h.timestamps = Hashie::Mash.new
        QUEUES.each {|q| h.timestamps["#{q}_last"] = time}
        z << h
      end
      z
    end

    # Process conditions into useful hashie/mash on intialize
    def initialize_conditions(what_conditions)
      what_conditions = cull_invalid(what_conditions) if self.minimal_author
      z = []
      what_conditions.each do |x|
        h = Hashie::Mash.new
        h.subject, h.attribute, h.query, h.action = x[0].to_sym, x[1].to_sym, x[2].to_sym, x[4].to_sym
        h.weight = x[5].to_f || 1.to_f
        h.what = process_what(x[3])
        x[6].nil? ? h.scope = :all_subreddits : h.scope = x[6].to_sym
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

    # Remove all conflicting conditions when minimal_author is true
    def cull_invalid(what)
      remove = ["author_combined_karma", "author_link_karma", "author_comment_karma", "author_karma_ratio", "author_account_age"]
      what = what.reject {|x| x unless (x & remove).empty? }
      what
    end

    # Whitelist options, only allowable options (with their defaults if not specified) can be passed in on intitialization
    @@whitelisted_options= {timestamp_offset:0, destructive:false, minimal_author:false}
    
    @@whitelisted_options.keys.each do |o|
      define_method(o) { return @current_options[o] rescue nil}
    end

    def available_options
      ao = []
      @@whitelisted_options.each_key{|k| ao << k }
      ao.join(", ")
    end

    # timestamp_offset #set an initial time for polling queues, else agent will only work from time it first fetches forward
    # destructive      #if true, remove and approve items via reddit api; otherwise fetch, check, and score only
    # minimal_author   #poll reddit for author name only; faster but less informtion to work with, default false
    #                  #invalidates any condition relying on extended author information
    def initialize_options(options)
      options = options.inject({}){|memo,(k,v)| memo[k.to_sym] = v; memo}
      options[:timestamp_offset] = options[:timestamp_offset]*(60*60*24)
      @current_options = {}
      @@whitelisted_options.each {|k, v| @current_options[k] = options[k] || v}
      @current_options
    end

    def initialize_logger(custom_logger)
      @l = Logger.new(custom_logger)
      @l.formatter = proc do |severity, datetime, progname, msg|
        "[%s] %s\n" % [ datetime.strftime("%Y%m%d::%H:%M"), msg ]
      end
    end

    def login_moderator
      login(m_modrname,m_password) unless ( m_modrname.nil? || m_password.nil? )
      @uh = get_current_user(m_modrname).uh
    end

    # Fetch results for this agent
    # subreddits must be in an array!
    def fetch(subreddits = current_subreddits, queues = QUEUES)
      subreddits.each do |s|
        queues.each { |x| fetch_recent(x, s) } unless queues.nil?
      end
    end
 
    # Check the current by q 
    def check(subreddits = current_subreddits, queues = QUEUES)
      subreddits.each do |s|
        queues.each { |x|
          @scope = s
          @scope_which = x 
          check_results(s["#{x}_recent"]) }
      end
    end

    # Score the current by q 
    def score(subreddits = current_subreddits, queues = QUEUES)
      subreddits.each do |s|
        queues.each { |x| score_results(s["#{x}_recent"]) }
      end
    end

    # Process the current by q
    def process(subreddits = current_subreddits, queues = QUEUES)
      subreddits.each do |s|
        queues.each { |x| process_results(s["#{x}_recent"]) }
      end
    end

    # Do it all with one command
    def manage_subreddits
      fetch
      check 
      score
      process if self.destructive       
    end

  end
end
