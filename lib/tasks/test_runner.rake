namespace :test do
  desc "Run model tests"
  task models: :environment do
    puts "Running model tests..."
    system "bundle exec rails test test/models/"
  end

  desc "Run controller tests"
  task controllers: :environment do
    puts "Running controller tests..."
    system "bundle exec rails test test/controllers/"
  end

  desc "Run integration tests"
  task integration: :environment do
    puts "Running integration tests..."
    system "bundle exec rails test test/integration/"
  end

  desc "Run system tests"
  task system: :environment do
    puts "Running system tests..."
    system "bundle exec rails test:system"
  end

  desc "Run all tests with detailed output"
  task all_verbose: :environment do
    puts "==============================================================================="
    puts "Crystal Plates Database - Complete Test Suite"
    puts "==============================================================================="
    puts

    puts "Model Tests:"
    puts "-------------------------------------------------------------------------------"
    system "bundle exec rails test test/models/"
    puts

    puts "Controller Tests:"
    puts "-------------------------------------------------------------------------------"
    system "bundle exec rails test test/controllers/"
    puts

    puts "Integration Tests:"
    puts "-------------------------------------------------------------------------------"
    system "bundle exec rails test test/integration/"
    puts

    puts "System Tests:"
    puts "-------------------------------------------------------------------------------"
    system "bundle exec rails test:system"
    puts

    puts "All Tests (Summary):"
    puts "-------------------------------------------------------------------------------"
    system "bundle exec rails test"
    puts

    puts "==============================================================================="
    puts "Test suite completed!"
    puts "==============================================================================="
  end
end

desc "Run all tests (shortcut for rake test:all_verbose)"
task test_all: "test:all_verbose"
