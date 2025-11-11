module ActiveRecordTemporalTests
  module TransactionTime
    def transaction_time
      ActiveRecord::Base.transaction do
        yield

        ActiveRecord::Base.connection.execute("select now() as time").first["time"]
      end
    end
  end
end
