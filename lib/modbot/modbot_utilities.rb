module ModbotUtilities

  #misc stuff in useful/informative form
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

  def current_conditions
    @conditions
  end

  def current_subreddits
    @subreddits
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
      processing = [] << processing # processing = [processing]
      clean_up(processing)
    end
  end

  def clean_up(clean)
    c = clean.reject { |s| s.empty? }
    c.compact.flatten.uniq
  end

  #process subreddits on intialize
  def process_subreddits(what_subreddits)
    z = []
    what_subreddits.each do |x|
      h = Hashie::Mash.new
      h.name, h.report_limit, h.spam_limit, h.submission_limit = x[0], x[1], x[2], x[3]
      z << h
    end
    z
  end

  #process conditions on intialize
  def process_conditions(what_conditions)
    z = []
    what_conditions.each do |x|
      h = Hashie::Mash.new
      h.subject, h.attribute, h.query, h.action = x[0].to_sym, x[1].to_sym, x[2].to_sym, x[4].to_sym
      h.what = process_what(x[3])
      case h.query
      when :matches
        h.what = Regexp.union(h.what)
      when :contains
        tt = []
        h.what.each do |t|
          tt << Regexp.new(Regexp.escape(t))
        end
        h.what = Regexp.union tt
      end
      z << h
    end
    z
  end
  
  def relevant_conditions(subject)
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
