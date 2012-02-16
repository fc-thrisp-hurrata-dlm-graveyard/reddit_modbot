module ModbotScore

  def score(input, selection)
    input.select { |x| x[0] == selection }.collect {|x,y| y}.inject(:+).to_f
  end

  def score_results(results_set)
    results_set.each do |item|
      item.score = score(item.verdict, :approve) / score(item.verdict, :remove)
      @l.info "#{item.verdict} yields a score of #{item.score} for item #{item.fullid}"
    end
  end

end
