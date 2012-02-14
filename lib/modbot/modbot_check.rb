module ModbotCheck

  #Checks for items with more reports than the subreddit's threshold.
  def check_alerts(subreddit_alert, results_count, subreddit)
    if subreddit.send(subreddit_alert) <= results_count
      message = "alert : #{results_count} exceed #{subreddit.send(subreddit_alert)} items for #{subreddit.name}"
      perform_alert(:conditions, m_modrname, message)
      @l.info message
    end
  end

  #Check a results set
  def check_results(results_set)
    results_set.each { |i| check_conditions(i) }
    @l.info "all conditions checked from this result set"
  end

  #Checks an item against a set of (relevant) conditions.
  def check_conditions(item)
    conditions = relevant_conditions(item.kind.to_sym)
    conditions.each do |c| #unless conditions.empty? 
      check_condition(c, item)
      @l.info "condition #{[c.subject, c.attribute, c.query, c.what, c.action]} checked"
    end
  end

  #Checks an item against a single condition.
  def check_condition(condition, item)
    #refactor with some sort of hash table or is adding more burden
    #available_conditions = { author: item.author.name,
    #                          title: item.title, 
    #                          body: item.body, 
    #                          domain: (URI(item.url).host),
    #                          self_post: item.is_self, 
    #                          account_age: item.author.user_age,
    #                          link_karma: item.author.link_karma,
    #                          comment_karma: item.author.comment_karma,
    #                          combined_karma: (item.author.link_karma + item.author.comment_karma)}
    case condition.attribute
    when :author
      i = item.author.name
    when :title
      i = item.title
    when :body
      i = item.body
    when :domain
      i = URI(item.url).host
    #when :url #not even close, will take some tweaking, do not use right now
    #  i = []
    #  item.url.each do |ii|
    #    ii = URI(ii)
    #    i << [ii.host, ii.path].reject { |s| s.empty? }
    #  end
    #  i.flatten
    when :self_post
      i = item.is_self
    when :account_age
      i = item.author.user_age
    when :link_karma
      i = item.author.link_karma
    when :comment_karma
      i = item.author.comment_karma
    when :combined_karma
      i = (item.author.link_karma + item.author.comment_karma)
    end
    @l.info "#{i} to be checked if #{condition.query} #{condition.attribute}"
    test_condition(condition, item, i)
  end
        
  #processes an outcome of a test, stores in the item
  def test_condition(condition, item, test_item)
    test = query_test_condition(condition, test_item)
    if test.kind_of?(Integer) || test == true
      item.verdict << condition.action
      test_result = true
    elsif test.nil? || test == false
      item.verdict << :fail
      test_result = false 
    else
      test_result = "failure"
    end
    @l.info "#{test_item} ::: #{condition.query} #{condition.what} ::: #{test_result}, recommend #{condition.action}"
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

end
