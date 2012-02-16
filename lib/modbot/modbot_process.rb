module ModbotProcess

  def analyze_score(item)
    case item.score
    when item.score.infinite?
      action = item.action
    when item.score.nan? || item.verdict.empty? || item.score.empty?
      action = :inconclusive
    else
      item.score >= 1 ? action = :approve : action = :remove
    end
    return action
  end

  def track_alerts(item)
    perform_action(:alert, item) if item.verdict.count {|x| x == :alert } >= 1 
  end

  def perform_alert(who=self.m_modrname, alert_type=:default, contents="nothing")
    send_reddit_message(who, "#{alert_type} alert from #{self.to_s}", contents)
  end
       
  def perform_action(action, item)
    case action
    when :inconclusive
      @l.info "not enough data to approve, remove, or call alert for #{item.fullid}, item not relevant to supplied conditions"
    when :approve
      self.approve(item.fullid)
      @l.info "approved #{item.fullid}" # improve description 
    when :remove
      self.remove(item.fullid)
      @l.info "removed #{item.fullid}" # improve description
    when :alert
      self.perform_alert(self.m_modrname, :item, "Alert triggered for #{item.kind} #{item.fullid} :: #{item.author} :: #{item.inspect}")
    else
      @l.info "Oddly, nothing to perform but perform action triggered"
    end
  end

  def process_results(results_set)
    results_set.each do |item|
      track_alerts(item)
      action = analyze_score(item)
      perform_action(action, item)
    end
  end

end
