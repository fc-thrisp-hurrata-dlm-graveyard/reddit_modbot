A moderation 'bot' for scripting regular forum moderator tasks, currently works with reddit

Use
---

1. Install as gem in your system or project and require as needed

2. Generate new instance

    m = Modbot::Agent.new(:pass_config) #from a yaml file (in the root of your directory)

    m = Modbot::Agent.new(:pass_arg, moderator = {'name' => '', 'password' => ''},
                                 subreddits = [[], [], []]
                                 conditions = [ [], [], []]) #this is the default


  - Moderator: As a hash { 'name' => '', 'password' => ''}, or see config file example.

  - Subreddits: As an array of arrays or see config file example. First three numbers are thresholds for reports, spam, and submissions respectively, the last is the item fetch limit for the subreddit (e.g. you know your subreddit and can pick a useful number defaults to 25 items at a time.

  - Conditions: As an array of arrays containing strings, see config file example. Each condition is an array: [subject, attribute, query, item to query, action, weight]
 
    - subject: submitted_link, comment

    - attribute: author, title, domain, url(avoid this atm), self_post, account_age, link_karma, comment_karma, combined_karma]

    - query: matches (complete phrase or word), contains (matches each quoted phrase or word), is_less_than, is_greater_than

    - what: your words, phrases, or number

    - action: approve, remove, alert

    - weight: assign a numerical weighting to this condition; higher numbers make that condition action more likely when condition is true for a post or comment

3. Use as needed

    m.manage_subreddits

   This will fetch, check, score, and process (if destructive set to true) items in reports, spam, and new submissions for the subreddits in this instance

See code for a breakdown on carrying out specific acts (fetch, check, score, process)

available options

    timestamp_offset      set an initial time in the past for polling queues, else agent will only work from time it first fetches forward
    
    destructive           if true, remove and approve items via reddit api; otherwise fetch, check, and score only
    
    minimal_author        poll reddit for author name only; faster but less information to work with, default false
                          agent will invalidate any condition relying on extended author information passed to it if this is true
    
    #shadow                creates a special condition that is an array of user names, use tbd but allows dynamic shadow bans of a sort


TODO
---

- tests/spec

- refactor, refactor, refactor

- refined condition testing options

- configurable logger, allow specification of logger to hook into by init choice 

- improved notifications for removals --- comment on the item

- improved config file intialization

Think about
---

  - wrappers modularization, e.g. use a modbot instance for a specific api, decouple from reddit and allow numerous api types
