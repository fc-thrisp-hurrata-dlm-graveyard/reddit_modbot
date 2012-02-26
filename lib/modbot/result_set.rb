class ResultSet
  include Enumerable

  def initialize(results, scope)
    @results = results
    @scope = scope
  end

  def each(&block)
    @results.each do |result|
      block.call(result)
    end
  end

end
