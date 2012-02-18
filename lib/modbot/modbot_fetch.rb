module ModbotFetch

    #Checks reported items for any matching conditions: report, spam, or submission
    def fetch_results(which_q, subreddit)
      which_to = self.method("get_reddit_#{which_q}s")
      timestamp = get_timestamp(which_q, subreddit, which_to)
      proceed = compare_timestamp(subreddit.timestamps["#{which_q}_last"], timestamp)
      if proceed
        results = which_to.call(subreddit.name, subreddit.item_limit) 
        @l.info "#{results.count} results from #{which_q}"
        results = compare_times(which_q, results)
        if results.empty?
          subreddit["#{which_q}_recent"] = []
          @l.info "nothing to report, #{which_q} is empty" 
        else
          check_alerts("#{which_q}_threshold".to_sym, results.count, subreddit)
          subreddit["#{which_q}_recent"] = results
          @l.info "#{results.count} new items from #{which_q} to check"
        end
      else
        @l.info "nothing new for #{which_q}"
      end
    end

    #see if time has changed on newest item, filter for only items newer than last check
    def compare_times(which_q, subreddit, results)
      if subreddit.timestamps.send(which_q.to_sym).nil?
        @l.info "this is the most recent set of results for #{which_q}"
        if results.empty?
           subreddit.timestamps["#{which_q}_last"] = Time.now.to_f.round(3)
        else
           subreddit.timestamps["#{which_q}_last"] = results[0].timestamp
        end 
        results = results
      else
        what_time = (which_q + '_last').to_sym
        time_to_check = subreddit.timestamps.send(what_time)
        results = results.select { |r| r.timestamp > time_to_check }
        subreddit.timestamps[(which_q +'_last')] = results[0].timestamp
        @l.info "#{which_q} results filtered against most recent time of check, new timestamp #{results[0].timestamp}"
      end
      results
    end

   def compare_timestamp(subreddit_timestamp, timestamp)
     if subreddit.timestamp >= timestamp
       return false
     else
       return true
     end
   end

  def get_timestamp(which_q, subreddit, which_to)
    result = which_to.call(subreddit.name, 1)
    subreddit.timestamps["#{which_q}_last"] = result[0].timestamp if subreddit.timestamps["#{which_q}_last"].nil?
    result[0].timestamp 
  end

end
