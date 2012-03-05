module ModbotScore

  def score_verdict(input, selection)
    input.select { |x| x[0] == selection }.collect {|x,y| y}.inject(:+).to_f
  end

  def formatted_item_verdict(item_verdict)
    item_verdict.select {|x| x[0] == :remove || x[0] == :approve }
  end

  def score_results(results_set)
    results_set.each do |item|
      item.score = score_verdict(item.verdict, :approve) / score_verdict(item.verdict, :remove)
      final = formatted_item_verdict(item.verdict)
      if final.count > 0
        @l.info "#{final} yields a score of #{item.score} for item #{item.fullid} at #{item.item_link}"
      end
    end
  end

end
