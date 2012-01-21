# -*- encoding: utf-8 -*-
require 'rubygems' unless Object.const_defined?(:Gem)
require File.dirname(__FILE__) + "/lib/boson/all/version"

Gem::Specification.new do |s|
  s.name        = "boson-all"
  s.version     = Boson::All::VERSION
  s.authors     = ["Gabriel Horner"]
  s.email       = "gabriel.horner@gmail.com"
  s.homepage    = "http://github.com/cldwalker/boson-all"
  s.summary = "boson2 plugins"
  s.description =  "A collection of boson plugins that can be mixed and matched"
  s.required_rubygems_version = ">= 1.3.6"
  s.executables = ['boson']
  s.add_dependency 'alias', '>= 0.2.2'
  s.add_development_dependency 'mocha'
  s.add_development_dependency 'bacon', '>= 1.1.0'
  s.add_development_dependency 'mocha-on-bacon'
  s.add_development_dependency 'bacon-bits'
  s.add_development_dependency 'bahia', '>= 0.3.0'
  s.files = Dir.glob(%w[{lib,test}/**/*.rb bin/* [A-Z]*.{txt,rdoc} ext/**/*.{rb,c} **/deps.rip]) + %w{Rakefile .gemspec}
  s.extra_rdoc_files = ["README.rdoc", "LICENSE.txt"]
  s.license = 'MIT'
end