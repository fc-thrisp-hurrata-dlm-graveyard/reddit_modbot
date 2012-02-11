module ModbotUtilities

  #misc stuff to useful form
  def internet_agent
    @r
  end

  def m_modrname
    @m_modrname
  end

  def m_password
    @m_password
  end
 
  def m_uh
    @uh
  end

  def timestamps_top 
    @timestamps
  end

  #takes arrays or single item returns array, useful for 'what' processing 
  def process_what(processing) 
    if processing.kind_of?(Array)
      processing = processing
    else
      processing = [] << processing
    end
    p = processing.reject { |s| s.empty? }
    p.compact.flatten.uniq
  end

  #returns subreddits put into this instance
  def current_subreddits
    z = []
    self.subreddits.each do |x|
      h = Hashie::Mash.new
      h.name, h.report_limit, h.spam_limit, h.submission_limit = x[0], x[1], x[2], x[3]
      z << h
    end
    z
  end

  #returns conditions put into this instance
  def current_conditions
    z = []
    conditions.each do |x|
      h = Hashie::Mash.new
      h.subject, h.attribute, h.query, h.what, h.action = x[0].to_sym, x[1].to_sym, x[2].to_sym, process_what(x[3]), x[4].to_sym
      z << h
    end
    z
  end
  
  def current_conditions_bysubject(subject)
    current_conditions.select { |x| x.subject == subject } 
  end

  #dev
  def m_pack
    [@m_modrname, @m_password, @uh]
  end

  #dev
  def belch_out_agent
    @r.inspect
  end

end
