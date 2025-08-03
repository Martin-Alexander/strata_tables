# frozen_string_literal: true

RSpec.describe HistoryTables do
  let(:connection) { ActiveRecord::Base.connection }

  it "creates a column" do
    connection.add_column(:books, :name, :string)

    expect(connection.column_exists?(:books, :name)).to be true
  end
end
