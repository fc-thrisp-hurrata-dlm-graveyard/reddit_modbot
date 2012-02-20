class ResultSet
  include Enumerable

  def initialize(results)
    @results = results
  end

  def each(&block)
    @results.each do |result|
      block.call(result)
    end
  end

end
