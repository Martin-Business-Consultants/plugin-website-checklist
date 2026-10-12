# The plugin's tests run inside a Runwell checkout, whose own tests don't load plugins. From
# Runwell's directory, with this plugin linked (bin/rails "plugins:link[path]"):
#
#   bin/rails test path/to/website_checklist/test
#
# This loads the plugin before Runwell boots, runs Runwell's test setup (fixtures, sign_in_as),
# then adds the plugin's tables to the test database.
ENV["RAILS_ENV"] = "test"
ENV["PARALLEL_WORKERS"] ||= "1"
runwell = ENV.fetch("RUNWELL", Dir.pwd)

require File.join(runwell, "config/boot")
require "rails"
$LOAD_PATH.unshift File.expand_path("../lib", __dir__)
require "website_checklist"
require File.join(runwell, "test/test_helper")

ActiveRecord::Migration.verbose = false
ActiveRecord::Base.connection_pool.then do |pool|
  ActiveRecord::MigrationContext.new([ File.expand_path("../db/migrate", __dir__) ], pool.schema_migration, pool.internal_metadata).migrate
end
