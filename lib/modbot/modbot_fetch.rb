module ModbotFetch

  #main method to manage recent q items in spam, report, submissions
  def fetch_recent(which_q, subreddit)
    which_to = self.method("get_reddit_#{which_q}s")
    timestamp = get_timestamp(which_q, subreddit, which_to)
    proceed = compare_timestamp(subreddit.timestamps["#{which_q}_last"], timestamp)
    if proceed
      results = fetch_results(which_q, subreddit, which_to)
      results = filterby_timestamp(which_q, subreddit, results) unless results.nil?
      store_results(results)
    else
      subreddit["#{which_q}_recent"] = []
      @l.info "nothing new for #{subreddit.name}::#{which_q}"
    end
  end

  def get_timestamp(which_q, subreddit, which_to)
    result = which_to.call(subreddit.name, 1)
    result[0].nil? ? time = Time.now.to_f : time = result[0].timestamp 
    if subreddit.timestamps["#{which_q}_last"].nil?#factor out to where?
      @agent_start.nil? ? subreddit.timestamps["#{which_q}_last"] = time : subreddit.timestamps["#{which_q}_last"] = @agent_start
    end
    time 
  end

  def compare_timestamp(subreddit_timestamp, timestamp)
    subreddit_timestamp >= timestamp
  end

  #go to reddit for reslts
  def fetch_results(which_q, subreddit, which_to)
    results = which_to.call(subreddit.name, subreddit.item_limit) 
    @l.info "#{results.count} results from #{subreddit.name}::#{which_q}"
    results.nil? ? results = [] : results = results 
    results
  end

  #see if time has changed on newest item, filter for only items newer than last check
  def filterby_timestamp(which_q, subreddit, results)
    time_to_filter = subreddit.timestamps["#{which_q}_last"]
    results = results.select { |r| r.timestamp > time_to_filter }
    subreddit.timestamps["#{which_q}_last"] = results[0].timestamp || Time.now.to_f#hmmm
    @l.info "#{subreddit.name}::#{which_q} results filtered against most recent time of check, new timestamp #{subreddit.timestamps["#{which_q}_last"]}"
    results
  end

  #store results in variable for checking
  def store_results(results)
    if results.empty?
      subreddit["#{which_q}_recent"] = []
      @l.info "nothing to report, #{subreddit.name}::#{which_q} is empty" 
    else
      #check_alerts("#{which_q}_threshold".to_sym, results.count, subreddit)
      subreddit["#{which_q}_recent"] = results
      @l.info "#{results.count} new items from #{subreddit.name}::#{which_q} to check"
    end
  end

end
