Just the basics for moderation, from a previous version. Abstracted to bot
class you can do with what you want whenever, removing db and web based
interaction concerns to your preferred solution.

Use
---

Install as gem in your system or project

Use Modbot::ModBot.new instance passing in moderator, subreddits, and conditions 
OR specify a yaml config file to be read (reads from root of project or irb/pry 
instance -- still needs tweaking)

    Modbot::ModBot.new(:pass_config)

    Modbot::ModBot.new(:pass_arg,
                       moderator = {'name' => '', 'password' => ''},
                       subreddits = [[], [], []]
                       conditions = [ [], [], []])  # this is the default

- Moderator: As a hash { 'name' => '', 'password' => ''}, or see config file example.

- Subreddits: As an array of arrays or see config file example. Numbers are limits for reports, spam, and submissions respectively

- Conditions: As an array of arrays containing strings, see config file example. Each condition is an array: [subject, attribute, query, item to query, action]
 
  - subject: submitted_link, comment

  - attribute: author, title, domain, url(avoid this atm), self_post, min_account_age, min_link_karma, min_comment_karma, min_combined_karma]

  - query: matches (complete phrase or word), contains (matches each quoted phrase or word), is_less_than, is_greater_than

  - what: your words, phrases, or number

  - action: approve, remove, alert(does nothing atm)

TODO / Issues
---

- everything is sort of bits and pieces atm 

- tests and testing

- regular actions, refine what it is supposed to do exactly(check reddit mod queues and respond appropriately)

- refined condition testing options

- The current rate limiting seems to affect EVERYTHING

- conditions should be configured carefully....a quick run throughs have shown
  that items can be removed and approved and removed and approved, etc et al. with conflicting results. Perhaps some sort of summary/decision addition to the process
  on a decisions, hmmmm



Think about
---

  - wrappers modularization, e.g. use a modbot instance for a specific api, decouple from reddit and allow numerous api types
