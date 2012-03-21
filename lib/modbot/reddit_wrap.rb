#ad hoc reddit api wrapper
require 'json'
module RedditWrap

  REDDIT_ROOT = %q[http://www.reddit.com]

  def reddit_route(fragment)
    "#{REDDIT_ROOT}#{fragment}"
  end

  # http://www.reddit.com/user/#{USER_NAME}/about/.json
  def get_current_user(user)
    h = Hashie::Mash.new
    x = @internet_agent.get reddit_route("/user/#{user}/about/.json")
    x = JSON.parse(x.body)
    h.user_name = x['data']['name']
    h.uh = x['data']['modhash']
    h 
  end

  # https://ssl.reddit.com/api/login/
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

  # http://www.reddit.com/r/#{SUBREDDIT}/new.json
  def get_reddit_submissions(reddit_name, limit = 300)
    #route = "http://www.reddit.com/r/#{reddit_name}/new.json"
    #q_parse(route, limit)
    q_parse(reddit_route("/r/#{reddit_name}/new/.json"), limit)
  end

  # http://www.reddit.com/r/#{SUBREDDIT}/about/reports/.json
  def get_reddit_reports(reddit_name, limit = 100)
    #route = "http://www.reddit.com/r/#{reddit_name}/about/reports/.json"
    #q_parse(route, limit)
    q_parse(reddit_route("/r/#{reddit_name}/about/reports/.json"), limit)
  end

  # http://www.reddit.com/r/#{SUBREDDIT}/about/spam/.json
  def get_reddit_spams(reddit_name, limit = 300)
    #route = "http://www.reddit.com/r/#{reddit_name}/about/spam/.json"
    #q_parse(route, limit)
    q_parse(reddit_route("/r/#{reddit_name}/about/spam/.json"), limit)
  end

  # http://www.reddit.com/api/compose/.json
  def send_reddit_message(user, subject, text)
    @internet_agent.post reddit_route('/api/compose'), 
            'to'=> user,
            'subject'=> subject,
            'text'=> text, 
            'uh' => @uh,
            'api_type' => 'json'
  end

  # http://www.reddit.com/user/#{USER_NAME}/about/.json# users other than the current mod
  def reddit_user(name)
    begin
      x = @internet_agent.get reddit_route("/user/#{name}/about.json")
      x = JSON.parse(x.body)
      y = Hashie::Mash.new
      y.author, y.author_created, y.author_age = x['data']['name'], x['data']['created'], user_age( x['data']['created'] )
      y.author_link_karma, y.author_comment_karma = x['data']['link_karma'], x['data']['comment_karma']
      y.author_combined_karma = ( (x['data']['link_karma'].to_f) + (x['data']['comment_karma'].to_f) )
      y.author_karma_ratio = (x['data']['link_karma'].to_f / x['data']['comment_karma'].to_f).round(3)
      y
    rescue
      @l.info "problem with getting user #{name} information"
      y = Hashie::Mash.new
      y.author, y.author_created, y.author_link_karma, y.author_comment_karma, y.author_age, y.author_karma_ratio = name, Time.now.to_f, 0, 0, 0, 0
      y
    end 
  end

  # http://www.reddit.com/api/approve/.json
  def approve(id)
    @internet_agent.post reddit_route('/api/approve'), 
            'id' => id , 
            'uh' => @uh,
            'api_type' => 'json'
  end

  # http://www.reddit.com/remove/.json
  def remove(id)
    @internet_agent.post reddit_route('/api/remove'), 
            'id' => id , 
            'uh' => @uh,
            'api_type' => 'json'
  end

  # handle bans?

  # misc utility methods
  # general fetch and parse of admin queues (report, spam, new)
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
          h.item_link = provide_link(yy)#reddit_route(yy['data']['permalink'])
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
          if self.minimal_author
            h.author = yy['data']['author']
          else 
            h.merge(reddit_user(yy['data']['author']))
          end
          z << h
        end
      end
      z
    rescue #Errno::ETIMEDOUT, Timeout::Error, Net::HTTPNotFound
      @l.info "problem with route #{route}"
    end
  end

  # provides a direct link for the item for eventual response to comment or link submission
  def provide_link(from_what)
    if from_what['kind'] == "t1"
     begin
       x = @internet_agent.get reddit_route("/by_id/#{from_what['data']['link_id']}.json")
       y = JSON.parse(x.body)['data']['children']
       link = "#{y.first['data']['url']}#{from_what['data']['id']}"
     rescue
        @l.info "link #{from_what['data']['link_id']} unavailable at this time"
     end
    elsif from_what['kind'] == "t3"
     link = from_what['data']['url'] 
    else
      link = "#{REDDIT_ROOT}/unknown"
    end
    link
  end

  # returns a usable value for user age 
  def user_age(from_when)
    (((( ( Time.at(Time.now) - Time.at(from_when) )/ 60 )/ 60)/ 24).to_i)
  end

end
