require "rails_helper"

RSpec.describe "Intent and stress policies" do
  it "routes every committed intent fixture correctly" do
    rows = JSON.parse(Rails.root.join("spec/fixtures/intents.json").read)
    expect(rows).to all(satisfy { |row| IntentPolicy.classify(row.fetch("text")) == row.fetch("expected") })
  end

  it "does not treat upload frustration as emotional stress" do
    expect(StressPolicy.explicit_level("My photo upload failed and the button is annoying")).to eq("neutral")
  end

  it "detects explicit elevated and urgent language conservatively" do
    expect(StressPolicy.explicit_level("I feel overwhelmed")).to eq("elevated")
    expect(StressPolicy.explicit_level("I might hurt myself")).to eq("urgent")
    expect(StressPolicy.explicit_level("I need a moment")).to be_nil
  end
end
