module ModbotProcess

  def process_results(results_set)
    results_set.each do |item|
      track_alerts(item)
      if v.verdict.empty?
        @l.info "Not enough information to make a decision on this item"
      else
        verdict = item.verdict.count {|x| x == :approve }.to_f / item.verdict.count {|x| x == :remove }.to_f
        if verdict.infinite?
          verdict = 1
          action = v.action
        elsif verdict.nan?
          verdict = 0
          action = :inconclusive
        else
          verdict >= 1 ? action = :approve : action = :remove
        end
        item.score = verdict
        @l.info "#{v.verdict} yields a score of #{v.score} for item #{v.fullid}"
        perform_action(action, v)
      end
    end
  end

  def track_alerts(item)
    perform_action(:alert, item) if item.verdict.count {|x| x == :alert } >= 1 
  end 
       
  def perform_action(action, item)
    case action
    when :inconclusive
      @l.info "not enough data to approve, remove, or call alert for #{item.fullid}"
    when :approve
      self.approve(item.fullid)
      @l.info "approved #{item.fullid}" # improve description 
    when :remove
      self.remove(item.fullid)
      @l.info "removed #{item.fullid}" # description
    when :alert
      self.perform_alert(:item, "Alert triggered for #{item.kind} #{item.fullid} :: #{item.author} :: #{item.inspect}")
    else
      @l.info "Oddly, nothing to perform but perform action triggered"
    end
  end

  def perform_alert(alert_type, who = @m_modrname,  contents = [])
    case :alert_type
    when :item
      send_reddit_message(m_modrname, "item alert - #{self.to_s}", contents)
    when :conditions
      send_reddit_message(m_modrname, "conditions alert - #{self.to_s}", contents)
    when :other_reddit
      send_reddit_message(who, "alert from - #{self.to_s}", contents)
    end
  end

end
