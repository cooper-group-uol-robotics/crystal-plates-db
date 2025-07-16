namespace :chemicals do
  desc "Import chemicals from Sciformation database"
  task :import_from_sciformation, [ :department_id, :cookie ] => :environment do |t, args|
    department_id = args[:department_id] || "124"
    cookie = args[:cookie] || ENV["SCIFORMATION_COOKIE"]

    if cookie.blank?
      puts "Error: No Sciformation cookie provided."
      puts "Usage: rails chemicals:import_from_sciformation[department_id,cookie]"
      puts "   or: SCIFORMATION_COOKIE=your_cookie rails chemicals:import_from_sciformation"
      exit 1
    end

    puts "Starting Sciformation import for department #{department_id}..."

    result = Chemical.fetch_from_sciformation(department_id: department_id, cookie: cookie)

    if result[:success]
      puts "\n✅ Import completed successfully!"
      puts "📊 Results:"
      puts "   - New chemicals created: #{result[:imported]}"
      puts "   - Existing chemicals updated: #{result[:updated]}"
      puts "   - Records skipped: #{result[:skipped]}"
      puts "   - Total records processed: #{result[:total_records]}"
      puts "   - Total chemicals in database: #{result[:total_chemicals]}"

      if result[:errors].any?
        puts "\n⚠️  Errors encountered:"
        result[:errors].each { |error| puts "   - #{error}" }
      end
    else
      puts "\n❌ Import failed: #{result[:error]}"
      exit 1
    end
  end

  desc "Import chemicals from JSON file"
  task :import_from_file, [ :file_path ] => :environment do |t, args|
    file_path = args[:file_path]

    if file_path.blank?
      puts "Error: No file path provided."
      puts "Usage: rails chemicals:import_from_file[path/to/file.json]"
      exit 1
    end

    unless File.exist?(file_path)
      puts "Error: File '#{file_path}' not found."
      exit 1
    end

    puts "Starting import from file: #{file_path}..."

    result = Chemical.import_from_file(file_path)

    if result[:success]
      puts "\n✅ Import completed successfully!"
      puts "📊 Results:"
      puts "   - New chemicals created: #{result[:imported]}"
      puts "   - Existing chemicals updated: #{result[:updated]}"
      puts "   - Records skipped: #{result[:skipped]}"
      puts "   - Total records processed: #{result[:total_records]}"
      puts "   - Total chemicals in database: #{result[:total_chemicals]}"

      if result[:errors].any?
        puts "\n⚠️  Errors encountered:"
        result[:errors].each { |error| puts "   - #{error}" }
      end
    else
      puts "\n❌ Import failed: #{result[:error]}"
      exit 1
    end
  end

  desc "Show chemical statistics"
  task stats: :environment do
    total = Chemical.count
    with_cas = Chemical.where.not(cas: [ nil, "" ]).count
    with_storage = Chemical.where.not(storage: [ nil, "" ]).count
    with_barcode = Chemical.where.not(barcode: [ nil, "" ]).count

    puts "📊 Chemical Database Statistics:"
    puts "   - Total chemicals: #{total}"
    puts "   - With CAS numbers: #{with_cas} (#{(with_cas.to_f / total * 100).round(1)}%)"
    puts "   - With storage info: #{with_storage} (#{(with_storage.to_f / total * 100).round(1)}%)"
    puts "   - With barcodes: #{with_barcode} (#{(with_barcode.to_f / total * 100).round(1)}%)"

    recent = Chemical.where("created_at > ?", 1.week.ago).count
    puts "   - Added in last week: #{recent}"
  end
end
