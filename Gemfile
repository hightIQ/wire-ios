source 'https://rubygems.org'

ruby '3.3.1'

gem 'fastlane'
gem 'git'
gem 'httparty'
gem "xcode-install"

plugins_path = File.join(File.dirname(__FILE__), 'fastlane', 'Pluginfile')
eval_gemfile(plugins_path) if File.exist?(plugins_path)
