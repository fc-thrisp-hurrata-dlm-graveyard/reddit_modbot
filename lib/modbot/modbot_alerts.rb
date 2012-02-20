module ModbotAlerts

  #Checks for items with more reports than the subreddit's threshold.
  def check_alerts(subreddit_alert, results_count, subreddit)
    if subreddit.send(subreddit_alert) <= results_count
      message = "alert : #{results_count} exceed #{subreddit.send(subreddit_alert)} items for #{subreddit.name}"
      perform_alert(:conditions, m_modrname, message)
      @l.info message
    end
  end
 
  def track_alerts(item)
    perform_action(:alert, item) if item.verdict.count {|x| x == :alert } >= 1 
  end

  def perform_alert(who=self.m_modrname, alert_type=:default, contents="nothing")
    send_reddit_message(who, "#{alert_type} alert from #{self.to_s}", contents)
  end

end
