module ModbotCheck

  # Check a results set
  def check_results(results_set)
    results_set.each { |i| check_conditions(i) } unless results_set.empty?
    @scope["#{@scope_which}_recent"] = results_set.select {|x| x.keep == true}
    @l.info "items triggering no conditions discarded"
    @l.info "all conditions checked for each item from this result set for #{@scope.name}"
  end

  # Checks an item against a set of (relevant) conditions.
  def check_conditions(item)
    conditions = relevant_conditions(item.kind.to_sym, @scope.name)
    conditions.each do |c| #unless conditions.empty? 
      check_condition(c, item)
      @l.info "condition #{[c.subject, c.attribute, c.query, c.what, c.action]} checked"
    end
    item.keep = keep_or_discard(item)
  end

  # Checks an item against a single condition.
  def check_condition(condition, item)
    i = item.send(condition.attribute)
    @l.info "#{i} to be checked if #{condition.query} #{condition.attribute}"
    test_condition(condition, item, i)
  end
        
  # processes an outcome of a test, stores in the item
  # thoughts on item not used, required to pass through this method? --> create a hash to pass around as one blob
  def test_condition(condition, item, test_item)
    test = query_test_condition(condition, test_item)
    deliver_test_outcome(test, condition, item, test_item)
  end
     
  # tests an item against a condition, returns true or false
  def query_test_condition(condition, test_item)
    case condition.query 
    when :matches || :contains
      return ( condition.what =~ test_item )
    when :is_greater_than
      return ( test_item > condition.what )
    when :is_less_than
      return ( test_item < condition.what )
    end
  end

  # deliver test outcome
  def deliver_test_outcome(test, condition, item, test_item)
    if test.kind_of?(Integer) || test == true
      item.verdict.unshift([condition.action, condition.weight])
      test_result = true
      @l.info "#{test_item} ::: #{condition.query} #{condition.what} ::: #{item.test_result}, recommend #{condition.action}"
    elsif test.nil? || test == false
      item.verdict << [:fail, 0]
      test_result = false
      @l.info "#{test_item} ::: #{condition.query} #{condition.what} ::: #{test_result}, recommend no action"
    else
      test_result = :failure
      @l.info "#{test_item} ::: test failure or inconclusive"
    end
  end
  
  # filter a set of conditions to only the conditions needed
  def relevant_conditions(subject, subreddit_scope)
    c = current_conditions.select { |x| x.subject == subject }
    cc = c.select { |x| x.scope == :all_subreddits || x.scope == subreddit_scope}
    cc  
  end
  
  # if item isn't meaningful for any interpretation (i.e. no relevant info from test), discard
  def keep_or_discard(item)
    item.verdict.select {|x| x[0] == :remove || x[0] == :approve}.count >= 1
  end

end
