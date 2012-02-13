#ad hoc reddit api wrapper
require 'json'
module RedditWrap

  #something more extensive to pull up all routes needed from simple cues
  #reddit_route('reports'
  #def reddit_route(route)
  #end

  #http://www.reddit.com/user/#{USER_NAME}/about/.json
  def get_current_user(user)
    h = Hashie::Mash.new
    x = @r.get 'http://www.reddit.com/user/' + user + '/about/.json'
    x = JSON.parse(x.body)
    h.user_name = x['data']['name']
    h.uh = x['data']['modhash']
    h 
  end

  #https://ssl.reddit.com/api/login/
  def login(user,password)
    begin
      @r.post 'https://ssl.reddit.com/api/login/' + user, 
          'passwd' => password,
          'user' =>  user, #appears required not redundant
          'type' => 'json'
    rescue
      #log 'unable to log in using the provided credentials'
    end
  end

  #http://www.reddit.com/r/#{SUBREDDIT}/new.json
  def get_reddit_submissions(reddit_name, limit = 50)
    route = 'http://www.reddit.com/r/' + reddit_name + '/new.json'
    q_parse(route, limit)
  end

  #http://www.reddit.com/r/#{SUBREDDIT}/about/reports/.json
  def get_reddit_reports(reddit_name, limit = 25)
    route = 'http://www.reddit.com/r/' + reddit_name + '/about/reports/.json'
    q_parse(route, limit)
  end

  #http://www.reddit.com/r/#{SUBREDDIT}/about/spam/.json
  def get_reddit_spams(reddit_name, limit = 50)
    route = 'http://www.reddit.com/r/'+ reddit_name + '/about/spam/.json'
    q_parse(route, limit)
  end

  #http://www.reddit.com/message/moderator/.json
  def send_reddit_message(user, subject, text)#or group
    @r.post 'http://www.reddit.com/api/compose', 
            'to'=> user,
            'subject'=> subject,
            'text'=> text, 
            'uh' => @uh,
            'api_type' => 'json'

  #http://www.reddit.com/user/#{USER_NAME}/about/.json
  def reddit_user(name)
    x = @r.get 'http://www.reddit.com/user/' + name + '/about.json'
    x = JSON.parse(x.body)
    y = [] 
    y << x['data']['name']
    y << x['data']['created']
    y << user_age( x['data']['created'] )
    y << x['data']['link_karma']
    y << x['data']['comment_karma']
    y << (x['data']['link_karma'].to_f / x['data']['comment_karma'].to_f).round(3)
    y
  end

  #http://www.reddit.com/api/approve
  def approve(id)
    @r.post 'http://www.reddit.com/api/approve', 
            'id' => id , 
            'uh' => @uh,
            'api_type' => 'json'
  end

  #http://www.reddit.com/remove
  def remove(id)
    @r.post 'http://www.reddit.com/api/remove', 
            'id' => id , 
            'uh' => @uh,
            'api_type' => 'json'
  end

  #misc utility methods
  def q_parse(route, limit)
    if limit == "none" 
      x = @r.get route
    else 
      x = @r.get route, 'limit' => limit
    end
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
        h.author = reddit_user(yy['data']['author'])
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
  end

  def user_age(from_when)
    (((( ( Time.at(Time.now) - Time.at(from_when) )/ 60 )/ 60)/ 24).to_i)
  end

end
