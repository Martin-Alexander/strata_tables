module ActiveRecordTemporalTests
  module TransactionTime
    def transaction_with_time(connection)
      connection.transaction do
        yield

        connection.execute("select now() as time").first["time"]
      end
    end
  end
end
