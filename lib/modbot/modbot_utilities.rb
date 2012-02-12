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

  def recent_spam
    @recent_spams
  end
  
  def recent_reports
    @recent_reports
  end

  def recent_submissions
    @recent_submissions
  end 

  def timestamps_top 
    @timestamps
  end

  #takes arrays or single item returns array, useful for 'what' processing 
  def process_what(processing) 
    if processing.kind_of?(Array)
      processing = processing
      clean_up(processing)
    elsif processing.kind_of?(Integer)
      processing = processing
    else
      processing = [] << processing
      clean_up(processing)
    end
  end

  def clean_up(clean)
    c = clean.reject { |s| s.empty? }
    c.compact.flatten.uniq
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
      h.subject, h.attribute, h.query, h.action = x[0].to_sym, x[1].to_sym, x[2].to_sym, x[4].to_sym
      h.what = process_what(x[3])
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
