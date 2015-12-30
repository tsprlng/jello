#!/usr/bin/ruby

# This file is for symlinking to; it will invoke jello.rb with the correct rvm config.
system('rvm', '2.2@tsprlng-jello', 'do', 'ruby', "#{__dir__}/jello.rb", *ARGV)
