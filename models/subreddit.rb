class Subreddit
  include DataMapper::Resource
  include ModelLogging

  has n, :rconditions

  property :id, Serial                 
  property :name, String               
  property :enabled, Boolean, :default => true           
  property :last_submission, DateTime  
  property :last_spam, DateTime        
  property :report_threshold, Integer
  property :spam_threshold, Integer

  #post create hook to create intial log entry
  #def set_log 
  #end
  
end
