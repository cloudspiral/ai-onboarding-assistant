require "json"
require "tempfile"
require "fileutils"

class PerformanceBenchmark
  RUNS = 20

  def run!
    result = {
      generated_at: Time.current.iso8601,
      runs: RUNS,
      ocr_latency_ms: summarize(ocr_runs),
      booking_latency_ms: summarize(booking_runs),
      thresholds: { ocr_p95_ms: 8_000, booking_p95_ms: 1_000 }
    }
    result[:passed] = result.dig(:ocr_latency_ms, :p95) < 8_000 && result.dig(:booking_latency_ms, :p95) < 1_000
    path = Pathname.new(ENV.fetch("ARTIFACT_DIR", Rails.root.join("docs").to_s)).join("performance-service-results.json")
    FileUtils.mkdir_p(path.dirname)
    File.write(path, JSON.pretty_generate(result) + "\n")
    puts "OCR      #{RUNS} runs | p95 #{result.dig(:ocr_latency_ms, :p95)} ms | max #{result.dig(:ocr_latency_ms, :max)} ms"
    puts "Booking  #{RUNS} runs | p95 #{result.dig(:booking_latency_ms, :p95)} ms | max #{result.dig(:booking_latency_ms, :max)} ms"
    puts "Result   #{result[:passed] ? 'PASS' : 'FAIL'}"
    raise "Performance thresholds were not met" unless result[:passed]
    result
  end

  private

  def ocr_runs
    source = Rails.root.join("spec/fixtures/ocr/images/synthetic-id-01.png")
    RUNS.times.map do
      tempfile = Tempfile.new([ "ocr-benchmark", ".png" ])
      FileUtils.cp(source, tempfile.path)
      upload = Struct.new(:path, :size, :content_type, :original_filename, :tempfile).new(tempfile.path, tempfile.size, "image/png", "synthetic.png", tempfile)
      started = monotonic
      result = OcrService.new.extract(upload)
      raise "OCR benchmark failed" unless result.success?
      elapsed(started)
    end
  end

  def booking_runs
    RUNS.times.map do |index|
      session = OnboardingSession.create!(user_id: format("44444444-4444-4444-8444-%012d", index))
      slot = AppointmentSlot.create!(starts_at: 1.year.from_now + index.minutes)
      started = monotonic
      AppointmentSlot.transaction do
        locked = AppointmentSlot.lock.find(slot.id)
        session.create_booking!(appointment_slot: locked, reference: format("PB-%04d", index))
      end
      duration = elapsed(started)
      session.destroy!
      slot.destroy!
      duration
    end
  end

  def summarize(values)
    sorted = values.sort
    { median: sorted[(sorted.length * 0.5).ceil - 1], p95: sorted[(sorted.length * 0.95).ceil - 1], max: sorted.max }
  end
  def monotonic = Process.clock_gettime(Process::CLOCK_MONOTONIC)
  def elapsed(started) = ((monotonic - started) * 1000).round
end
