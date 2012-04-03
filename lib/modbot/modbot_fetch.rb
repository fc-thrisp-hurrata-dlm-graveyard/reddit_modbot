module ModbotFetch

  #get recent queue items from spam, report, new submissions after comparing timestamps for new items
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
    result.first.nil? ? time = Time.now.to_f : time = result.first.timestamp 
    time 
  end

  #compare the timestamp of the most recent item with most recent recorded for subreddit
  def compare_timestamp(subreddit_last, time_recent)
    subreddit_last <= time_recent
  end

  #go to reddit for results, return results
  def fetch_results(which_q, subreddit, which_to)
    results = which_to.call(subreddit.name, subreddit.item_limit)
    @l.info "results fetched from #{subreddit.name}::#{which_q}"
    results.nil? ? results = [] : results = results 
    results
  end

  #filter out old items
  def filterby_timestamp(which_q, subreddit, results)
    if results.first.nil? || results.empty?#obvious screwy logic is screwy
      results = results
    else
      time_to_filter = subreddit.timestamps["#{which_q}_last"]
      top_time = results.first.timestamp
      results = results.select { |r| r.timestamp > time_to_filter }
      subreddit.timestamps["#{which_q}_last"] = top_time
      @l.info "#{subreddit.name}::#{which_q} results filtered against most recent time of check, new timestamp #{subreddit.timestamps["#{which_q}_last"]}"
      results
    end
  end

  #store results for use
  def store_results(subreddit, which_q, results)
    if results.empty?
      subreddit["#{which_q}_recent"] = []
      @l.info "nothing to report, #{subreddit.name}::#{which_q} is empty" 
    else
      subreddit["#{which_q}_recent"] = results
      @l.info "#{results.count} new items from #{subreddit.name}::#{which_q} to check"
    end
  end

end
