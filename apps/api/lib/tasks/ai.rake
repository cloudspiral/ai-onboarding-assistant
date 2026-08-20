namespace :ai do
  desc "Run the synthetic OCR, intent, stress, and safety evaluation scorecard"
  task eval: :environment do
    AiEvaluation.new.run!
  end
end
