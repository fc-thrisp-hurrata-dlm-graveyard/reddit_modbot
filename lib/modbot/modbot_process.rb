module ModbotProcess

  # Analyze a result's score in a result set
  def analyze_score(item)
    case item.score
    when item.score.infinite?
      action = item.action
    when item.score.nan? || item.verdict.empty? || item.score.empty?
      action = :inconclusive
    else
      item.score >= 1 ? action = :approve : action = :remove
    end
  end

  # Perform an action on reddit       
  def perform_action(action, item)
    case action
    when :inconclusive
      @l.info "not enough data to approve, remove, or call alert for #{item.fullid}, item not relevant to supplied conditions"
    when :approve
      self.approve(item.fullid)
      @l.info "approved #{item.fullid}"
    when :remove
      self.remove(item.fullid)
      @l.info "removed #{item.fullid}"
    when :alert
      self.perform_alert(self.m_modrname, :item, "Alert triggered for #{item.kind} #{item.fullid} :: #{item.author} :: #{item.inspect}")
    else
      @l.info "Oddly, nothing to perform but perform action triggered"
    end
  end

  # Analyze fetched, checked, and scored results set and take action (approve, remove, alert) where necessary
  def process_results(results_set)
    check_alerts("#{which_q}_threshold".to_sym, results.count, subreddit)
    results_set.each do |item|
      track_alerts(item)
      action = analyze_score(item)
      perform_action(action, item)
    end
  end

end
