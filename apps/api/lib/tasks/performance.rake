namespace :performance do
  desc "Run 20 local OCR and transactional booking benchmark iterations"
  task benchmarks: :environment do
    PerformanceBenchmark.new.run!
  end
end
