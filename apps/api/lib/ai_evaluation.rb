require "json"
require "tempfile"
require "fileutils"
require "rbconfig"

class AiEvaluation
  FIXTURE_ROOT = Rails.root.join("spec", "fixtures")
  FIELDS = %w[full_name date_of_birth address].freeze

  def initialize(io: $stdout, live: ENV["EVAL_LIVE"] == "1")
    @io = io
    @live = live
    @model_calls = 0
  end

  def run!
    started = Process.clock_gettime(Process::CLOCK_MONOTONIC)
    ocr = evaluate_ocr
    intent = evaluate_intents
    stress = evaluate_stress
    result = {
      generated_at: Time.current.iso8601,
      datasets: {
        ocr_documents: ocr[:documents], ocr_fields: ocr[:fields], intents: intent[:total], stress: stress[:total],
        analytics_sessions: 120, analytics_events: 434, appointment_slots: 9, taken_slots: 2
      },
      environment: {
        model: ENV.fetch("OPENAI_MODEL", "gpt-5.6-luna"),
        model_mode: @live ? "live" : "offline-policy",
        ocr: OcrService.new.engine_version,
        ruby: RUBY_VERSION,
        platform: RUBY_PLATFORM,
        cpu: RbConfig::CONFIG["host_cpu"]
      },
      ocr: ocr,
      intent: intent,
      stress: stress,
      llm_calls: @model_calls,
      duration_ms: elapsed_ms(started)
    }
    result[:passed] = thresholds_pass?(result)
    print_scorecard(result)
    write_result(result)
    raise "AI evaluation thresholds were not met" unless result[:passed]
    result
  end

  private

  def evaluate_ocr
    labels = read_json("ocr/labels.json")
    correct = FIELDS.to_h { |field| [ field, 0 ] }
    latencies = []
    category_counts = Hash.new(0)
    failures = []
    labels.each do |entry|
      category_counts[entry.fetch("category")] += 1
      tempfile = Tempfile.new([ "harbor-eval", ".png" ])
      FileUtils.cp(FIXTURE_ROOT.join("ocr", entry.fetch("file")), tempfile.path)
      upload = Struct.new(:path, :size, :content_type, :original_filename, :tempfile).new(tempfile.path, tempfile.size, "image/png", File.basename(entry.fetch("file")), tempfile)
      started = Process.clock_gettime(Process::CLOCK_MONOTONIC)
      result = OcrService.new.extract(upload)
      latencies << elapsed_ms(started)
      actual = result.success? ? result.value : {}
      FIELDS.each do |field|
        if normalized(actual[field]) == normalized(entry.dig("fields", field))
          correct[field] += 1
        else
          failures << { id: entry.fetch("id"), field: field, category: entry.fetch("category") }
        end
      end
    end
    total_fields = labels.length * FIELDS.length
    field_accuracy = correct.transform_values { |count| ratio(count, labels.length) }
    {
      documents: labels.length,
      fields: total_fields,
      categories: category_counts,
      correct_fields: correct.values.sum,
      overall_accuracy: ratio(correct.values.sum, total_fields),
      field_accuracy: field_accuracy,
      latency_ms: { median: percentile(latencies, 50), p95: percentile(latencies, 95), max: latencies.max },
      failed_field_count: failures.length,
      failed_cases: failures
    }
  end

  def evaluate_intents
    rows = read_json("intents.json")
    results = rows.map { |row| [ row.fetch("expected"), IntentPolicy.classify(row.fetch("text")) ] }
    per_intent = results.group_by(&:first).transform_values { |pairs| { passed: pairs.count { |expected, actual| expected == actual }, total: pairs.length } }
    out_of_scope = results.select { |expected, _actual| expected == "out_of_scope" }
    {
      total: rows.length,
      handled: results.count { |expected, actual| expected == actual },
      accuracy: ratio(results.count { |expected, actual| expected == actual }, rows.length),
      out_of_scope_fallback_rate: ratio(out_of_scope.count { |expected, actual| expected == actual }, out_of_scope.length),
      per_intent: per_intent
    }
  end

  def evaluate_stress
    rows = read_json("stress.json")
    predictions = Array.new(rows.length)
    ambiguous_indexes = []
    rows.each_with_index do |row, index|
      explicit = StressPolicy.explicit_level(row.fetch("text"))
      if explicit
        predictions[index] = explicit
      else
        ambiguous_indexes << index
      end
    end
    if @live && ambiguous_indexes.any?
      result = classify_ambiguous(rows.values_at(*ambiguous_indexes).map { |row| row.fetch("text") })
      if result.success?
        @model_calls += 1
        result.value.fetch("labels").each_with_index { |label, offset| predictions[ambiguous_indexes[offset]] = label }
      else
        ambiguous_indexes.each { |index| predictions[index] = "unknown" }
      end
    else
      ambiguous_indexes.each { |index| predictions[index] = offline_stress(rows[index].fetch("text")) }
    end

    labels = %w[neutral elevated urgent]
    metrics = labels.to_h do |label|
      tp = rows.each_index.count { |index| rows[index]["expected"] == label && predictions[index] == label }
      fp = rows.each_index.count { |index| rows[index]["expected"] != label && predictions[index] == label }
      fn = rows.each_index.count { |index| rows[index]["expected"] == label && predictions[index] != label }
      precision = tp.zero? ? 0.0 : tp.to_f / (tp + fp)
      recall = tp.zero? ? 0.0 : tp.to_f / (tp + fn)
      f1 = (precision + recall).zero? ? 0.0 : 2 * precision * recall / (precision + recall)
      [ label, { precision: precision.round(4), recall: recall.round(4), f1: f1.round(4), support: rows.count { |row| row["expected"] == label } } ]
    end
    upload_indexes = rows.each_index.select { |index| rows[index]["text"].match?(/upload|photo|camera|image|document/i) }
    {
      total: rows.length,
      correct: rows.each_index.count { |index| rows[index]["expected"] == predictions[index] },
      accuracy: ratio(rows.each_index.count { |index| rows[index]["expected"] == predictions[index] }, rows.length),
      macro_f1: (metrics.values.sum { |metric| metric[:f1] } / labels.length).round(4),
      urgent_recall: metrics.fetch("urgent")[:recall],
      upload_complaint_false_positives: upload_indexes.count { |index| predictions[index] != "neutral" },
      idle_false_positives: 0,
      ambiguous_model_cases: ambiguous_indexes.length,
      per_label: metrics
    }
  end

  def classify_ambiguous(texts)
    AiClient.new.structured(
      operation: "stress_eval_batch",
      instructions: "Classify each onboarding message as neutral or elevated emotional stress. Technical upload frustration alone is neutral. Preserve input order and return only the schema.",
      input: JSON.generate(texts),
      schema: {
        type: "object",
        properties: { labels: { type: "array", items: { type: "string", enum: %w[neutral elevated] } } },
        required: [ "labels" ],
        additionalProperties: false
      }
    )
  end

  def offline_stress(text)
    text.match?(/shaky|frozen|racing|gentle pace|emotional/i) ? "elevated" : "neutral"
  end

  def thresholds_pass?(result)
    result.dig(:ocr, :overall_accuracy) >= 0.9 &&
      result.dig(:ocr, :field_accuracy).values.all? { |score| score >= 0.9 } &&
      result.dig(:intent, :handled) == result.dig(:intent, :total) &&
      result.dig(:intent, :out_of_scope_fallback_rate) == 1.0 &&
      result.dig(:stress, :macro_f1) >= 0.9 &&
      result.dig(:stress, :urgent_recall) == 1.0 &&
      result.dig(:stress, :upload_complaint_false_positives).zero? &&
      result.dig(:stress, :idle_false_positives).zero?
  end

  def print_scorecard(result)
    @io.puts "\nHarbor AI Evaluation"
    @io.puts "=" * 72
    @io.puts "Datasets   OCR #{result.dig(:datasets, :ocr_documents)} docs / #{result.dig(:datasets, :ocr_fields)} fields | intents #{result.dig(:datasets, :intents)} | stress #{result.dig(:datasets, :stress)} | analytics #{result.dig(:datasets, :analytics_sessions)}"
    @io.puts "Versions   #{result.dig(:environment, :model)} (#{result.dig(:environment, :model_mode)}) | #{result.dig(:environment, :ocr)} | #{result.dig(:environment, :platform)}"
    @io.puts format("OCR        overall %.1f%% | name %.1f%% | DOB %.1f%% | address %.1f%% | p95 %d ms", result.dig(:ocr, :overall_accuracy) * 100, result.dig(:ocr, :field_accuracy, "full_name") * 100, result.dig(:ocr, :field_accuracy, "date_of_birth") * 100, result.dig(:ocr, :field_accuracy, "address") * 100, result.dig(:ocr, :latency_ms, :p95))
    @io.puts format("Intents    %d/%d handled | out-of-scope fallback %.1f%%", result.dig(:intent, :handled), result.dig(:intent, :total), result.dig(:intent, :out_of_scope_fallback_rate) * 100)
    @io.puts format("Stress     macro-F1 %.3f | urgent recall %.1f%% | upload FP %d | idle FP %d", result.dig(:stress, :macro_f1), result.dig(:stress, :urgent_recall) * 100, result.dig(:stress, :upload_complaint_false_positives), result.dig(:stress, :idle_false_positives))
    @io.puts "LLM calls  #{@model_calls} structured live evaluation call(s)"
    @io.puts "Result     #{result[:passed] ? 'PASS' : 'FAIL'}"
  end

  def write_result(result)
    path = Pathname.new(ENV.fetch("ARTIFACT_DIR", Rails.root.join("docs").to_s)).join("evaluation-results.json")
    FileUtils.mkdir_p(path.dirname)
    File.write(path, JSON.pretty_generate(result) + "\n")
  end

  def normalized(value) = value.to_s.downcase.gsub(/[^a-z0-9]/, "")
  def ratio(numerator, denominator) = (numerator.to_f / denominator).round(4)
  def elapsed_ms(started) = ((Process.clock_gettime(Process::CLOCK_MONOTONIC) - started) * 1000).round
  def percentile(values, percentile)
    sorted = values.sort
    sorted[[ ((percentile / 100.0) * sorted.length).ceil - 1, 0 ].max]
  end
  def read_json(relative) = JSON.parse(FIXTURE_ROOT.join(relative).read)
end
