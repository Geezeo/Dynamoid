$LOAD_PATH.unshift(File.join(File.dirname(__FILE__), '..', 'lib'))
$LOAD_PATH.unshift(File.dirname(__FILE__))

MODELS = File.join(File.dirname(__FILE__), "app/models")

require 'fake_dynamo'
require 'rspec'
require 'dynamoid'
require 'mocha/api'

# Requires supporting files with custom matchers and macros, etc,
# in ./support/ and its subdirectories.
Dir["#{File.dirname(__FILE__)}/support/**/*.rb"].each {|f| require f}

RSpec.configure do |config|
  db_path = Dir::Tmpname.make_tmpname [File.join(Dir.tmpdir, 'fake_dynamo-'), '.fdb'], nil
  config.mock_with(:mocha)

  config.before(:suite) do
    FakeDynamo::Storage.db_path = db_path

    monitor = Monitor.new
    lock = monitor.new_cond
    monitor.synchronize do
      dynamo_thread = Thread.start do
        FakeDynamo::Server.run!(bind: '127.0.0.1') do |server|
          monitor.synchronize { lock.signal }
        end
      end

      lock.wait
    end

    Dynamoid.configure do |config|
      config.adapter = 'aws_sdk'
      config.endpoint = '127.0.0.1:4567'
      config.namespace = 'dynamoid_tests'
      config.use_ssl = false
    end

    Dynamoid.logger.level = Logger::FATAL

    Dir[ File.join(MODELS, "*.rb") ].sort.each { |file| require file }
  end

  config.before(:each) do
    Dynamoid::Adapter.list_tables.each do |table|
      if table =~ /^#{Dynamoid::Config.namespace}/
        table = Dynamoid::Adapter.get_table(table)
        table.items.each {|i| i.delete}
      end
    end
  end

  config.after(:suite) do
    Dynamoid::Adapter.list_tables.each do |table|
      Dynamoid::Adapter.delete_table(table) if table =~ /^#{Dynamoid::Config.namespace}/
    end

    File.unlink db_path
  end
end
