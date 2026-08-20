module Result
  Success = Data.define(:value, :metadata) do
    def success? = true
  end

  Failure = Data.define(:code, :message, :retryable, :metadata) do
    def success? = false
  end
end
