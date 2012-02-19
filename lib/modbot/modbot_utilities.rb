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

end
