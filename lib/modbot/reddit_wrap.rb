#ad hoc reddit api wrapper
require 'json'
module RedditWrap

  REDDIT_ROOT = %q[http://www.reddit.com]

  def reddit_route(fragment)
    "#{REDDIT_ROOT}#{fragment}"
  end

  #http://www.reddit.com/user/#{USER_NAME}/about/.json
  def get_current_user(user)
    h = Hashie::Mash.new
    x = @internet_agent.get "http://www.reddit.com/user/#{user}/about/.json"
    x = JSON.parse(x.body)
    h.user_name = x['data']['name']
    h.uh = x['data']['modhash']
    h 
  end

  #https://ssl.reddit.com/api/login/
  def login(user,password)
    begin
      @internet_agent.post "https://ssl.reddit.com/api/login/#{user}", 
          'passwd' => password,
          'user' =>  user,
          'type' => 'json'
    rescue
      @l.info "unable to login to reddit with the provided credentials"
    end
  end

  #http://www.reddit.com/r/#{SUBREDDIT}/new.json
  def get_reddit_submissions(reddit_name, limit = 300)
    route = "http://www.reddit.com/r/#{reddit_name}/new.json"
    q_parse(route, limit)
  end

  #http://www.reddit.com/r/#{SUBREDDIT}/about/reports/.json
  def get_reddit_reports(reddit_name, limit = 100)
    route = "http://www.reddit.com/r/#{reddit_name}/about/reports/.json"
    q_parse(route, limit)
  end

  #http://www.reddit.com/r/#{SUBREDDIT}/about/spam/.json
  def get_reddit_spams(reddit_name, limit = 300)
    route = "http://www.reddit.com/r/#{reddit_name}/about/spam/.json"
    q_parse(route, limit)
  end

  #http://www.reddit.com/api/compose/.json
  def send_reddit_message(user, subject, text)
    @internet_agent.post 'http://www.reddit.com/api/compose', 
            'to'=> user,
            'subject'=> subject,
            'text'=> text, 
            'uh' => @uh,
            'api_type' => 'json'
  end

  #http://www.reddit.com/user/#{USER_NAME}/about/.json# users other than the current mod
  def reddit_user(name)
    begin
      x = @internet_agent.get "http://www.reddit.com/user/#{name}/about.json"
      x = JSON.parse(x.body)
      y = Hashie::Mash.new
      y.name, y.created, y.link_karma, y.comment_karma = x['data']['name'], x['data']['created'], x['data']['link_karma'], x['data']['comment_karma']
      y.user_age = user_age( x['data']['created'] )
      y.karma_ratio = (x['data']['link_karma'].to_f / x['data']['comment_karma'].to_f).round(3)
      y
    rescue
      @l.info "problem with getting user #{name} information"
      y = Hashie::Mash.new
      y.name, y.created, y.link_karma, y.comment_karma, y.user_age, y.karma_ratio = name, Time.now.to_f, 0, 0, 0, 0
      y
    end 
  end

  #http://www.reddit.com/api/approve/.json
  def approve(id)
    @internet_agent.post 'http://www.reddit.com/api/approve', 
            'id' => id , 
            'uh' => @uh,
            'api_type' => 'json'
  end

  #http://www.reddit.com/remove/.json
  def remove(id)
    @internet_agent.post 'http://www.reddit.com/api/remove', 
            'id' => id , 
            'uh' => @uh,
            'api_type' => 'json'
  end

  #misc utility methods
  def q_parse(route, limit)
    begin 
      x = @internet_agent.get route, 'limit' => limit
      y = JSON.parse(x.body)['data']['children']
      z = []
      if y.empty?
        z
      else
        y.each do |yy|
          h = Hashie::Mash.new
          h.verdict = []
          h.timestamp = yy['data']['created']
          h.id = yy['data']['id']
          h.fullid = yy['data']['name']
          h.permalink = provide_link(yy)#reddit_route(yy['data']['permalink'])
          self.minimal_author ? h.author = yy['data']['author'] : reddit_user(yy['data']['author'])
          #h.author = reddit_user(yy['data']['author'])
          if yy['kind'] == "t1"
            h.kind = "comment"
            h.comment = yy['data']['body']
          elsif yy['kind'] == "t3"
            h.kind = "submitted_link"
            h.title = yy['data']['title']
            h.is_self = yy['data']['is_self']
            h.selftext = yy['data']['selftext']
            h.url = yy['data']['url']
          else
            h.kind = "wtf, something not a link or comment" 
          end
          z << h
        end
      end
      z
    rescue #Errno::ETIMEDOUT, Timeout::Error, Net::HTTPNotFound
      @l.info "problem with route #{route}"
    end
  end

  # provides a direct link for the item for eventual response, repsond to comment
  # or comment on a link submission
  def provide_link(from_what)
    if from_what['kind'] == "t1"
     x = @internet_agent.get reddit_route("/by_id/#{from_what['parent_id']}.json")
     y = JSON.parse(x.body)['data']['children']
     link = "#{y[0]['data']['url']}/#{from_what['id']}"
    elsif from_what['kind'] == "t3"
     link = from_what['url'] 
    else
      link = "#{REDDIT_ROOT}/unknown"
    end
    link
  end

  def user_age(from_when)
    (((( ( Time.at(Time.now) - Time.at(from_when) )/ 60 )/ 60)/ 24).to_i)
  end

end
