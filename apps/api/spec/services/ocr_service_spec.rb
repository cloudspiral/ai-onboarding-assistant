require "rails_helper"
require "tempfile"

RSpec.describe OcrService do
  Upload = Struct.new(:path, :size, :content_type, :original_filename, :tempfile)

  it "extracts the three labeled fields from a synthetic document" do
    source = Rails.root.join("spec/fixtures/ocr/images/synthetic-id-01.png")
    tempfile = Tempfile.new([ "ocr-spec", ".png" ])
    path = tempfile.path
    FileUtils.cp(source, tempfile.path)
    upload = Upload.new(tempfile.path, tempfile.size, "image/png", "synthetic.png", tempfile)

    result = described_class.new.extract(upload)
    expect(result).to be_success
    expect(result.value).to eq(
      "full_name" => "Avery Sample",
      "date_of_birth" => "1975-01-01",
      "address" => "100 Cedar Street, Sample City, IL 60000"
    )
    expect(File).not_to exist(path)
  end

  it "rejects mismatched and oversized uploads with typed failures" do
    tempfile = Tempfile.new([ "not-an-image", ".png" ])
    tempfile.write("not an image")
    tempfile.rewind
    result = described_class.new.extract(Upload.new(tempfile.path, tempfile.size, "image/png", "fake.png", tempfile))
    expect(result).not_to be_success
    expect(result.code).to eq("corrupt_image")
  end

  it "returns a clear typed failure when no file is supplied" do
    result = described_class.new.extract(nil)
    expect(result).not_to be_success
    expect(result.code).to eq("missing_file")
    expect(result.retryable).to be(false)
  end

  it "reports the installed OCR engine version" do
    expect(described_class.new.engine_version).to start_with("tesseract")
  end
end
