module ModbotFetch

  #main method to manage recent q items in spam, report, submissions
  def fetch_recent(which_q, subreddit)
    which_to = self.method("get_reddit_#{which_q}s")
    time_recent = get_time_recent(which_q, subreddit, which_to)
    proceed = compare_timestamp(subreddit.timestamps["#{which_q}_last"], time_recent)
    if proceed
      results = fetch_results(which_q, subreddit, which_to)
      results = filterby_timestamp(which_q, subreddit, results) unless results.empty?
      store_results(subreddit, which_q, results)
    else
      subreddit["#{which_q}_recent"] = []
      @l.info "nothing new for #{subreddit.name}::#{which_q}"
    end
  end

  #get the timestamp of most recent item in the queue
  def get_time_recent(which_q, subreddit, which_to)
    result = which_to.call(subreddit.name, 1)
    result[0].nil? ? time = Time.now.to_f : time = result[0].timestamp 
    time 
  end

  #compare the timestamp of the most recent item with most recent recorded for subreddit
  def compare_timestamp(subreddit_last, time_recent)
    subreddit_last <= time_recent
  end

  #go to reddit for results
  def fetch_results(which_q, subreddit, which_to)
    results = which_to.call(subreddit.name, subreddit.item_limit)
    @l.info "results fetched from #{subreddit.name}::#{which_q}"
    results.nil? ? results = [] : results = results 
    results
  end

  #filter for only items newer than last check
  def filterby_timestamp(which_q, subreddit, results)
    if results[0].nil? || results.empty?#obvious screwy logic is screwy, but I'll get it later :/
      results = results
    else
      time_to_filter = subreddit.timestamps["#{which_q}_last"]
      top_time = results[0].timestamp
      results = results.select { |r| r.timestamp > time_to_filter }
      subreddit.timestamps["#{which_q}_last"] = top_time
      @l.info "#{subreddit.name}::#{which_q} results filtered against most recent time of check, new timestamp #{subreddit.timestamps["#{which_q}_last"]}"
      results
    end
  end

  #store results in variable for checking
  def store_results(subreddit, which_q, results)
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
