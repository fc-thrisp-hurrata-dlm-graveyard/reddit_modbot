module ModbotCheck

  #Check a results set
  def check_results(results_set)
    results_set.each { |i| check_conditions(i) } unless results_set.empty?
    @scope["#{@scope_which}_recent"] = results_set.select {|x| x.keep == true}
    @l.info "items triggering no conditions discarded"
    @l.info "all conditions checked for each item from this result set for #{@scope.name}"
  end

  #Checks an item against a set of (relevant) conditions.
  def check_conditions(item)
    conditions = relevant_conditions(item.kind.to_sym, @scope.name)
    conditions.each do |c| #unless conditions.empty? 
      check_condition(c, item)
      @l.info "condition #{[c.subject, c.attribute, c.query, c.what, c.action]} checked"
    end
    item.keep = keep_or_discard(item)
  end

  #Checks an item against a single condition.
  def check_condition(condition, item)
    #refactor with some sort of hash table or would that add unnecessary burden
    available_conditions = { author: item.author.name,
                             title: item.title, 
                             body: item.body, 
                             domain: (URI(item.url).host),
                             self_post: item.is_self, 
                             account_age: item.author.user_age,
                             link_karma: item.author.link_karma,
                             comment_karma: item.author.comment_karma,
                             combined_karma: (item.author.link_karma + item.author.comment_karma)}
    available_conditions.each { |k,v|
      i = v if condition.attribute == k }
    #case condition.attribute
    #when :author
    #  i = item.author.name;
    #when :title
    #  i = item.title
    #when :body
    #  i = item.body
    #when :domain
    #  i = URI(item.url).host
    #when :url #not even close, will take some tweaking, do not use right now
    #  i = []
    #  item.url.each do |ii|
    #    ii = URI(ii)
    #    i << [ii.host, ii.path].reject { |s| s.empty? }
    #  end
    #  i.flatten
    #when :self_post
    #  i = item.is_self
    #when :account_age
    #  i = item.author.user_age
    #when :link_karma
    #  i = item.author.link_karma
    #when :comment_karma
    #  i = item.author.comment_karma
    #when :combined_karma
    #  i = (item.author.link_karma + item.author.comment_karma)
    #end
    @l.info "#{i} to be checked if #{condition.query} #{condition.attribute}"
    test_condition(condition, item, i)
  end
        
  #processes an outcome of a test, stores in the item
  def test_condition(condition, item, test_item)
    test = query_test_condition(condition, test_item)
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
     
  #tests an item against a condition, returns true or false
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

  def relevant_conditions(subject, subreddit_scope)
    c = current_conditions.select { |x| x.subject == subject }
    cc = c.select { |x| x.scope == :all_subreddits || x.scope == subreddit_scope}
    cc  
  end
  
  def keep_or_discard(item)
    item.verdict.select {|x| x[0] == :remove || x[0] == :approve}.count >= 1
  end

end
