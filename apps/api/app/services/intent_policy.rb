class IntentPolicy
  RESCHEDULE = /\b(reschedul|change|move|different|cannot make|can't make).*(appointment|booking|time|visit)|\b(cancel).*(appointment|booking|visit)/i
  OUT_OF_SCOPE = /\b(weather|recipe|stock|bitcoin|sports|score|capital of|movie|music|write code|tell me a joke)\b/i
  QUESTION = /\A\s*(what|when|where|why|how|can|could|will|is|are|do|does)\b|\?/i

  def self.classify(text)
    return "express_distress" if StressPolicy.explicit_level(text).in?(%w[elevated urgent])
    return "request_reschedule" if text.match?(RESCHEDULE)
    return "out_of_scope" if text.match?(OUT_OF_SCOPE)
    return "ask_question" if text.match?(QUESTION)

    "provide_details"
  end
end
