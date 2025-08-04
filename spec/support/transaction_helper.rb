module TransactionHelper
  def transaction_with_time(connection)
    connection.transaction do
      yield

      connection.execute("select timezone('UTC', now()) as time").first["time"]
    end
  end
end