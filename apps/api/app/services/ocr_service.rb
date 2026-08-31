require "open3"
require "marcel"
require "pathname"

class OcrService
  MAX_BYTES = 8.megabytes
  ALLOWED_TYPES = %w[image/jpeg image/png].freeze

  def extract(upload)
    validation = validate(upload)
    return validation unless validation.success?

    stdout, _stderr, status = Open3.capture3("tesseract", upload.path, "stdout", "--psm", "11")
    return Result::Failure.new(code: "ocr_unavailable", message: "We couldn't read that photo. You can try again or type your details.", retryable: true, metadata: {}) unless status.success?

    fields = parse(stdout)
    return Result::Failure.new(code: "no_text", message: "We couldn't read that photo. You can try again or type your details.", retryable: true, metadata: {}) if fields.values.all?(&:blank?)

    Result::Success.new(
      value: fields,
      metadata: { fields_found: fields.values.count(&:present?), engine: engine_version }
    )
  rescue Errno::ENOENT
    Result::Failure.new(code: "ocr_unavailable", message: "Photo reading is temporarily unavailable. Please type your details.", retryable: false, metadata: {})
  ensure
    upload&.tempfile&.close!
  end

  def engine_version
    stdout, = Open3.capture3("tesseract", "--version")
    stdout.lines.first.to_s.strip.presence || "unavailable"
  rescue Errno::ENOENT
    "unavailable"
  end

  private

  def validate(upload)
    return invalid("missing_file", "Choose a JPEG or PNG photo to continue.") unless upload.respond_to?(:path)
    return invalid("file_too_large", "That photo is over 8 MB. Choose a smaller JPEG or PNG.") if upload.size > MAX_BYTES
    return invalid("unsupported_type", "Choose a JPEG or PNG photo.") unless ALLOWED_TYPES.include?(upload.content_type)

    magic_type = Marcel::MimeType.for(Pathname.new(upload.path), name: upload.original_filename)
    return invalid("content_mismatch", "That file doesn't appear to be a valid JPEG or PNG.") unless ALLOWED_TYPES.include?(magic_type)

    _out, _err, status = Open3.capture3("identify", upload.path)
    return invalid("corrupt_image", "That image appears damaged. Try another photo or type your details.") unless status.success?

    Result::Success.new(value: true, metadata: {})
  end

  def invalid(code, message)
    Result::Failure.new(code:, message:, retryable: false, metadata: {})
  end

  def parse(text)
    normalized = text.encode("UTF-8", invalid: :replace, undef: :replace, replace: " ")
    {
      "full_name" => match_line(normalized, /(?:NAME|FULL NAME)\s*[:\-]?\s*(.+)/i),
      "date_of_birth" => normalize_date(match_line(normalized, /(?:DOB|DATE OF BIRTH)\s*[:\-]?\s*([0-9.\/\-]+)/i)),
      "address" => match_line(normalized, /(?:ADDRESS)\s*[:\-]?\s*(.+)/i)
    }
  end

  def match_line(text, pattern)
    text.match(pattern)&.captures&.first&.strip
  end

  def normalize_date(value)
    return if value.blank?

    Date.parse(value).iso8601
  rescue Date::Error
    nil
  end
end
