module ModbotUtilities

  #normalizes condition.what into for future processing  
  def process_what(processing) 
    if processing.kind_of?(Array)
      processing = processing
      clean_up(processing)
    elsif processing.kind_of?(Integer)
      processing = processing
    else
      processing = [] << processing # processing = [processing]
      clean_up(processing)
    end
  end

  def clean_up(clean)
    c = clean.reject { |s| s.empty? }
    c.compact.flatten.uniq
  end

  def relevant_conditions(subject)
    current_conditions.select { |x| x.subject == subject } 
  end

  #can be called from check, fetch, or process orphaned atm
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

  #dev
  #def m_pack
  #  [@m_modrname, @m_password, @uh]
  #end

  #dev
  #def belch_out_agent
  #  @internet_agent.inspect
  #end

end
