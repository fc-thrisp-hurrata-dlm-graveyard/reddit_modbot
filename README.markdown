A moderation 'bot' for scripting regular forum moderator tasks, currently works with reddit

Use
---

Install as gem in your system or project

Use Modbot::ModBot.new instance specifying arguments for moderator, subreddits, and conditions 
OR specify a yaml config file to be read (reads from root of project or irb/pry 
instance -- still needs tweaking)

    Modbot::ModBot.new(:pass_config)

    Modbot::ModBot.new(:pass_arg,
                       moderator = {'name' => '', 'password' => ''},
                       subreddits = [[], [], []]
                       conditions = [ [], [], []])  # this is the default

- Moderator: As a hash { 'name' => '', 'password' => ''}, or see config file example.

- Subreddits: As an array of arrays or see config file example. First three numbers are thresholds for reports, spam, and submissions respectively, the last is the item fetch limit for the subreddit (e.g. you know your subreddit and can pick a useful number defaults to 25 items at a time.

- Conditions: As an array of arrays containing strings, see config file example. Each condition is an array: [subject, attribute, query, item to query, action]
 
  - subject: submitted_link, comment

  - attribute: author, title, domain, url(avoid this atm), self_post, account_age, link_karma, comment_karma, combined_karma]

  - query: matches (complete phrase or word), contains (matches each quoted phrase or word), is_less_than, is_greater_than

  - what: your words, phrases, or number

  - action: approve, remove, alert(does nothing atm)

TODO
---

- everything is sort of bits and pieces atm 

- tests and testing

- refactor, refactor, refactor

- refined condition testing options, condition weighting and scoring


Think about
---

  - wrappers modularization, e.g. use a modbot instance for a specific api, decouple from reddit and allow numerous api types

  - condition weighting; certain conditions can take priority for remove/approve

notes 
    #main(fetch       -- results,
    #     compare     -- times,
    #     check       -- items/conditions,
    #     test        -- item what / condition attribute,
    #     process     -- check item verdicts
    #     perform     -- approve/remove/alert moderator )
