namespace :db do
  desc "Setup all databases for production deployment"
  task deploy: :environment do
    puts "🚀 Setting up databases for production deployment..."

    # Create and migrate primary database
    puts "\n📦 Setting up primary database..."
    begin
      Rake::Task["db:create"].invoke
      Rake::Task["db:migrate"].invoke
      puts "✅ Primary database setup completed"
    rescue => e
      puts "❌ Error setting up primary database: #{e.message}"
      raise e # Fail deployment if primary database fails
    end

    # Setup cache database
    puts "\n📦 Setting up cache database..."
    begin
      Rails.application.load_tasks unless defined?(Rake::Task["solid_cache:install"])
      Rake::Task["solid_cache:install"].invoke
      puts "✅ Cache database setup completed"
    rescue => e
      puts "⚠️  Warning setting up cache database: #{e.message}"
      # Don't fail deployment for cache database issues
    end

    # Setup queue database  
    puts "\n� Setting up queue database..."
    begin
      Rails.application.load_tasks unless defined?(Rake::Task["solid_queue:install"])
      Rake::Task["solid_queue:install"].invoke
      puts "✅ Queue database setup completed"
    rescue => e
      puts "⚠️  Warning setting up queue database: #{e.message}"
      # Don't fail deployment for queue database issues
    end

    # Setup cable database
    puts "\n📦 Setting up cable database..."
    begin
      Rails.application.load_tasks unless defined?(Rake::Task["solid_cable:install"])
      Rake::Task["solid_cable:install"].invoke
      puts "✅ Cable database setup completed"
    rescue => e
      puts "⚠️  Warning setting up cable database: #{e.message}"
      # Don't fail deployment for cable database issues
    end

    puts "\n🎉 Database setup completed!"
  end

  desc "Test Solid Queue functionality"
  task test_queue: :environment do
    puts "🧪 Testing Solid Queue functionality..."
    
    begin
      # Queue a test job
      job = TestJob.perform_later("Test from rake task at #{Time.current}")
      puts "✅ Test job queued successfully: #{job.job_id}"
      
      # Check if we can access the queue database
      total_jobs = SolidQueue::Job.count
      pending_jobs = SolidQueue::Job.where(finished_at: nil).count
      
      puts "📊 Queue statistics:"
      puts "   Total jobs: #{total_jobs}"
      puts "   Pending jobs: #{pending_jobs}"
      
    rescue => e
      puts "❌ Error testing Solid Queue: #{e.message}"
      puts "   #{e.backtrace.first}"
    end
  end

  desc "Check database connections"
  task check: :environment do
    puts "🔍 Checking database connections..."

    # Check primary database
    begin
      ActiveRecord::Base.connection.execute("SELECT 1")
      puts "✅ Primary database connection OK"
    rescue => e
      puts "❌ Primary database connection failed: #{e.message}"
    end

    # Check secondary databases by trying to connect to their tables
    [
      { name: "Cache", class: "SolidCache::Entry" },
      { name: "Queue", class: "SolidQueue::Job" },
      { name: "Cable", class: "SolidCable::Message" }
    ].each do |db_info|
      begin
        db_info[:class].constantize.connection.execute("SELECT 1")
        puts "✅ #{db_info[:name]} database connection OK"
      rescue => e
        puts "❌ #{db_info[:name]} database connection failed: #{e.message}"
      end
    end
  end
end
