Version history & notes
---

  0.1.0 'mostly functional'

    - modularized fetch, check, process
   
    - deliver a 'verdict' on each item based on what conditions the item passed for 

    - condition weighting to allow specification of condition precedence

  0.0.5

    - not much, some spec and moved to 0.1.0

  0.0.4
 
    - separated checking from fetching, most recent result sets are held e.g subreddit.spam_recent
   
    - added item verdict processing to sum result of testing/checking before acting 
    
    - began a final process method to process instance subreddits, and specify queues(report,submission,spam for all instance subreddits)    

    
  0.0.3

    - tossed stuff around, tuned and tweaked

  0.0.2
    
    - rate limit instance agent to once per second with simple Proc

    - config file sort of implemented
      intialialize from config file (via passed param of where) or pass into class instance
