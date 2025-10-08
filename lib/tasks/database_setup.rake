namespace :db do
  desc "Setup all databases for production deployment"
  task deploy: :environment do
    puts "🚀 Setting up databases for production deployment..."

    # Database configurations
    databases = {
      primary: ENV.fetch("DATABASE_NAME"),
      cache: ENV.fetch("CACHE_DATABASE_NAME", "crystal_plates_production_cache"),
      queue: ENV.fetch("QUEUE_DATABASE_NAME", "crystal_plates_production_queue"),
      cable: ENV.fetch("CABLE_DATABASE_NAME", "crystal_plates_production_cable")
    }

    # Create all databases
    puts "\n📦 Creating databases..."
    databases.each do |role, db_name|
      begin
        config = ActiveRecord::Base.configurations.configs_for(env_name: Rails.env, name: role.to_s)
        ActiveRecord::Tasks::DatabaseTasks.create(config.database_configuration)
        puts "✅ Created #{role} database: #{db_name}"
      rescue ActiveRecord::DatabaseAlreadyExists
        puts "ℹ️  #{role} database already exists: #{db_name}"
      rescue => e
        puts "❌ Error creating #{role} database: #{e.message}"
        # Don't fail deployment for database creation errors
      end
    end

    # Run migrations
    puts "\n🔄 Running migrations..."

    # Primary database migrations
    begin
      ActiveRecord::Base.connected_to(database: :primary) do
        ActiveRecord::Tasks::DatabaseTasks.migrate
      end
      puts "✅ Primary database migrated"
    rescue => e
      puts "❌ Error migrating primary database: #{e.message}"
      raise e # Fail deployment if primary migrations fail
    end

    # Secondary database migrations
    [ :cache, :queue, :cable ].each do |db_role|
      begin
        ActiveRecord::Base.connected_to(database: db_role) do
          migrations_path = case db_role
          when :cache then "db/cache_migrate"
          when :queue then "db/queue_migrate"
          when :cable then "db/cable_migrate"
          end

          if Dir.exist?(Rails.root.join(migrations_path))
            ActiveRecord::MigrationContext.new(Rails.root.join(migrations_path).to_s).migrate
            puts "✅ #{db_role.capitalize} database migrated"
          else
            puts "ℹ️  No migrations found for #{db_role} database"
          end
        end
      rescue => e
        puts "⚠️  Warning migrating #{db_role} database: #{e.message}"
        # Don't fail deployment for secondary database migration errors
      end
    end

    puts "\n🎉 Database setup completed!"
  end

  desc "Check database connections"
  task check: :environment do
    puts "🔍 Checking database connections..."

    [ :primary, :cache, :queue, :cable ].each do |db_role|
      begin
        ActiveRecord::Base.connected_to(database: db_role) do
          ActiveRecord::Base.connection.execute("SELECT 1")
          puts "✅ #{db_role.capitalize} database connection OK"
        end
      rescue => e
        puts "❌ #{db_role.capitalize} database connection failed: #{e.message}"
      end
    end
  end
end
