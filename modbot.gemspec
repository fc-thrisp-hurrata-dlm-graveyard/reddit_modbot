# -*- encoding: utf-8 -*-
$:.push File.expand_path("../lib", __FILE__)
require "modbot/version"

Gem::Specification.new do |s|
  s.name        = "modbot"
  s.version     = Modbot::VERSION
  s.authors     = ["blueblank"]
  s.email       = ["blueblank@gmail.com"]
  s.homepage    = ""
  s.summary     = %q{moderation bot (for reddit)}
  s.description = %q{moderation bot (for reddit)}

  s.rubyforge_project = "modbot"

  s.files         = `git ls-files`.split("\n")
  s.test_files    = `git ls-files -- {test,spec,features}/*`.split("\n")
  s.executables   = `git ls-files -- bin/*`.split("\n").map{ |f| File.basename(f) }
  s.require_paths = ["lib"]

  # specify any dependencies here; for example:
  # s.add_development_dependency "rspec"
  # s.add_runtime_dependency "rest-client"
  s.add_runtime_dependency "hashie" 
  s.add_runtime_dependency "json"
  s.add_runtime_dependency "mechanize" 
  #s.add_runtime_dependency 
end
