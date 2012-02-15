module ModbotProcess

  def process_results(results_set)
    results_set.each do |item|
      track_alerts(item)
      if item.verdict.empty?
        @l.info "Not enough information to make a decision on this item"
      else
        verdict = score(item.verdict, :approve) / score(item.verdict, :remove)
        score_verdict(item, verdict)
        perform_action(action, item)
      end
    end
  end

  def score(input, selection)
    input.select { |x| x[0] == selection }.collect {|x,y| y}.inject(:+).to_f
  end
      
    
  def score_verdict(item, verdict)
    case verdict
    when verdict.infinite?
      verdict = 1
      action = v.action
    when verdict.nan?
      verdict = "NaN"
      action = :inconclusive
    else
      verdict >= 1 ? action = :approve : action = :remove
    end
    item.score = verdict
    @l.info "#{item.verdict} yields a score of #{item.score} for item #{item.fullid}"
    return action
  end

  def track_alerts(item)
    perform_action(:alert, item) if item.verdict.count {|x| x == :alert } >= 1 
  end

  def perform_alert(who = self.m_modrname, alert_type, contents = [])
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
      @l.info "removed #{item.fullid}" # description
    when :alert
      self.perform_alert(self.m_modrname, :item, "Alert triggered for #{item.kind} #{item.fullid} :: #{item.author} :: #{item.inspect}")
    else
      @l.info "Oddly, nothing to perform but perform action triggered"
    end
  end

end
