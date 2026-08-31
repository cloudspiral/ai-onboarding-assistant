class StressPolicy
  URGENT = /\b(suicid|kill myself|hurt myself|can't stay safe|cannot stay safe|immediate danger|overdos)/i
  ELEVATED = /\b(overwhelm|panic|panicking|anxious|terrified|can't do this|cannot do this|too much|stressed)/i
  UPLOAD_COMPLAINT = /\b(upload|photo|camera|file|image|document).*(annoy\w*|fail\w*|broken|won't|cannot|can't|hard)\b/i

  CRISIS_RESPONSE = {
    level: "urgent",
    assistant_reply: "I’m sorry you’re dealing with this. Harbor’s onboarding assistant can’t provide crisis support. If you may be in immediate danger, call 911 now. In the U.S., call or text 988 for the Suicide & Crisis Lifeline.",
    next_actions: [ "pause", "continue_later" ]
  }.freeze

  def self.explicit_level(text)
    return "urgent" if text.match?(URGENT)
    return "elevated" if text.match?(ELEVATED)
    return "neutral" if text.match?(UPLOAD_COMPLAINT)

    nil
  end
end
