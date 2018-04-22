Gem::Specification.new do |gem|
  gem.author      = 'Team Geezeo!'
  gem.description = "Dynamoid is an ORM for Amazon's DynamoDB that supports offline development, associations, querying, and everything else you'd expect from an ActiveRecord-style replacement."
  gem.email       = 'developers@geezeo.com'
  gem.files       = Dir['lib/**/*.rb', 'spec/**/*.rb']
  gem.homepage    = 'http://geezeo.com'
  gem.license     = 'All rights reserved'
  gem.name        = 'dynamoid'
  gem.summary     = "Keeps your G's, yo."
  gem.version     = "0.5.0"

  gem.add_development_dependency 'mocha',         '~> 1.1'
  gem.add_development_dependency 'rake',          '~> 10.4'
  gem.add_development_dependency 'rspec',         '~> 3.2'
  gem.add_development_dependency 'bundler',       '~> 1.14'
  gem.add_development_dependency 'yard',          '>= 0'
  gem.add_development_dependency 'redcarpet',     '>= 1.17.2'
  gem.add_development_dependency 'github-markup', '>= 0'
  gem.add_development_dependency 'fake_dynamo',   '~> 0.1.3'

  gem.add_runtime_dependency     'activesupport', '< 6'
  gem.add_runtime_dependency     'activemodel',   '< 6'
  gem.add_runtime_dependency     'tzinfo',        '>= 0'
  gem.add_runtime_dependency     'aws-sdk-v1',    '>= 0'
  gem.add_runtime_dependency     'json',          '~> 1.8.3'
end
