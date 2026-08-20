#!/usr/bin/env ruby
require "json"
require "fileutils"
require "open3"

ROOT = File.expand_path("..", __dir__)
FIXTURES = File.join(ROOT, "spec", "fixtures")
IMAGE_DIR = File.join(FIXTURES, "ocr", "images")
FileUtils.mkdir_p(IMAGE_DIR)

categories = ([ "clean" ] * 12) + ([ "phone" ] * 8) + ([ "skewed" ] * 5) + ([ "glare" ] * 3) + ([ "hard" ] * 2)
first_names = %w[Avery Jordan Casey Morgan Riley Cameron Quinn Rowan Finley Skyler Parker Reese Taylor Sidney Devon Emery Arden Blake Drew Ellis Hayden Jules Kendall Lane Marley Noel Oakley Peyton Robin Sage]
last_names = %w[Sample Demo Test Harbor North Cedar Vale Brook West Lake Stone Grove Field Ridge Park Coast Hill River Green Woods Shore Plain Wells Ash Gray Frost Hart Bell Moss]
streets = %w[Cedar Willow Harbor Juniper Meadow Linden Walnut Cherry Sunset Spruce]

ocr = categories.each_with_index.map do |category, index|
  label = {
    "id" => format("synthetic-id-%02d", index + 1),
    "category" => category,
    "file" => format("images/synthetic-id-%02d.png", index + 1),
    "fields" => {
      "full_name" => "#{first_names[index]} #{last_names[index]}",
      "date_of_birth" => format("%04d-%02d-%02d", 1975 + (index % 25), (index % 12) + 1, (index % 27) + 1),
      "address" => "#{100 + index} #{streets[index % streets.length]} Street, Sample City, IL #{format('%05d', 60000 + index)}"
    }
  }
  content = "HARBOR SYNTHETIC ID\nNAME: #{label.dig('fields', 'full_name')}\nDOB: #{label.dig('fields', 'date_of_birth')}\nADDRESS: #{label.dig('fields', 'address')}\nNOT A REAL ID"
  output = File.join(FIXTURES, "ocr", label["file"])
  command = [ "convert", "-background", "#fffdf9", "-fill", "#2e2a26", "-font", "DejaVu-Sans", "-pointsize", "40", "-size", "1320x680", "-gravity", "west", "caption:#{content}", "-bordercolor", "#7a6bb5", "-border", "20x20" ]
  command += [ "-resize", "92%", "-bordercolor", "white", "-border", "55x55" ] if category == "phone"
  command += [ "-background", "white", "-rotate", index.even? ? "1.2" : "-1.2" ] if category == "skewed"
  command += [ "-fill", "rgba(255,255,255,0.30)", "-draw", "polygon 850,0 1120,0 720,760 460,760" ] if category == "glare"
  command += [ "-blur", "0x0.45", "-contrast" ] if category == "hard"
  command << output
  _stdout, stderr, status = Open3.capture3(*command)
  abort("Fixture generation failed: #{stderr.lines.first}") unless status.success?
  label
end
File.write(File.join(FIXTURES, "ocr", "labels.json"), JSON.pretty_generate(ocr) + "\n")

intent_phrases = {
  "provide_details" => [ "My name is Avery Sample", "I am registering for the first time", "I need an appointment soon", "Nothing else for the team", "I live in Sample City", "My birthday is January fifth", "I am transferring providers", "Just exploring for now", "Please note that mornings are best", "You can call me Riley" ],
  "ask_question" => [ "What happens after I register?", "Can I skip the photo?", "How long is the visit?", "Is the document image saved?", "Will a person review this?", "Where does my data go?", "Could I type the fields instead?", "Do I need to finish today?", "When can I book?", "Are video visits available?" ],
  "request_reschedule" => [ "I need to reschedule my appointment", "Can I change my booking time?", "Move my visit to another day", "Please cancel my appointment", "I need a different appointment", "Change the time of my visit", "Can we reschedule the booking?", "I cannot make my appointment", "Move my booking to Friday", "Cancel this visit please" ],
  "express_distress" => [ "I feel overwhelmed", "This is making me anxious", "I am panicking a little", "This is too much right now", "I feel stressed", "I cannot do this today", "I am terrified about starting", "I feel overwhelmed by these questions", "I am anxious about the visit", "This process is making me panic" ],
  "out_of_scope" => [ "What is the weather tomorrow?", "Tell me a joke", "What is the score of the game?", "Give me a pasta recipe", "Should I buy bitcoin?", "What is the capital of France?", "Recommend a movie", "Play some music", "Write code for a website", "What stock should I buy?" ]
}
intents = intent_phrases.flat_map { |intent, phrases| phrases.map { |text| { "text" => text, "expected" => intent } } }
File.write(File.join(FIXTURES, "intents.json"), JSON.pretty_generate(intents) + "\n")

neutral = [ "I am ready to continue", "That makes sense", "Nothing else right now", "I would like a morning time", "I am just exploring", "Please show the next step", "My answer is no", "I can finish this today", "I prefer a phone visit", "I need a moment to find the date", "The upload button is annoying", "My photo upload failed", "The camera is broken", "This image file will not upload", "The document photo is hard to read", "I have a question about privacy", "Can I type this instead?", "I want to change my appointment", "The page loaded slowly", "I am transferring from another provider" ]
elevated = [ "I feel overwhelmed", "I am really anxious", "I am panicking", "This is too much", "I feel stressed", "I cannot do this", "I am terrified", "These questions overwhelm me", "I am anxious about all of this", "This makes me panic", "I need this to slow down because I am overwhelmed", "I am too stressed to think", "I cannot focus because I am anxious", "This whole thing is too much right now", "I feel panicky about continuing", "My hands are shaky and I need smaller steps", "I feel frozen trying to answer", "My thoughts are racing while I do this", "I need a very gentle pace today", "I am having a hard emotional time with this" ]
urgent = [ "I might hurt myself", "I am thinking about suicide", "I cannot stay safe right now", "I am in immediate danger", "I might overdose tonight" ]
stress = neutral.map { |text| { "text" => text, "expected" => "neutral" } } + elevated.map { |text| { "text" => text, "expected" => "elevated" } } + urgent.map { |text| { "text" => text, "expected" => "urgent" } }
File.write(File.join(FIXTURES, "stress.json"), JSON.pretty_generate(stress) + "\n")

FileUtils.cp(File.join(IMAGE_DIR, "synthetic-id-01.png"), File.expand_path("../../web/public/sample-id.png", __dir__))
puts "Generated 30 OCR images (#{categories.tally}), 50 intents, and 45 stress examples."
