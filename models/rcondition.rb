class Rcondition
  include DataMapper::Resource
  
  belongs_to :subreddit

  property :id, Serial
  property :title, String
  property :subject, Enum[:submitted_link, :comment], :default => :comment
  property :rc_attribute, Enum[:author,
                               :title, 
                               :domain,
                               :url,
                               :body,
                               :self_post,
                               :min_account_age,
                               :min_link_karma,
                               :min_comment_karma,
                               :min_combined_karma], :default => :author
  property :rc_query, Enum[:matches,#exact phrase
                           :contains,#any of these words
                           :is_greater_than,
                           :is_less_than], :default => :contains
  property :rc_text_value, Text
  property :rc_integer_value, Integer
  property :rc_action, Enum[:approve, :remove, :alert], :default => :approve
  property :rc_regex, Regexp#post create hook, create regex, use == 1 db call, possibly

  after :create do
  end

  def gist
    a = []
    a << self.subject
    a << self.rc_attribute
    a << self.rc_query
    self.rc_text_value.nil? ? a << self.rc_integer_value : a << self.rc_text_value
    a << self.rc_action 
  end
 
  #return true or false
  def test_condition(i)
    case self.rc_query
    when :matches 
      test = (self.rc_regex =~ i)
      if test.nil?
        false
      else
        true
      end
      #return true or false
    when :contains
      self.rc_regex =~ i
      #return a true of false
    when :is_greater_than
      i > self.rc_integer_value
    when :is_less_than
      i < self.rc_integer_value 
    else
      false 
    end
  end 

  #after create hooks
  def set_rc_query
    if self.rc_query == :contains
      self.rc_regex = "placeholder contains"
    elsif self.rc_query == :matches
      self.rc_regex = "placeholder matches" # Regexp.union self.rc_text_value 
    else
    end 
  end

end
