module ModbotFetch

    #Checks reported items for any matching conditions: report, spam, or submission
    def fetch_results(which_q, subreddit)
      which_to = self.method("get_reddit_#{which_q}s")
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
    end

    #see if time has changed on newest item, filter for only items newer than last check
    def compare_times(which_q, results)
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

end
