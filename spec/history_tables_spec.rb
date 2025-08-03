RSpec.describe HistoryTables do
  let(:connection) { ActiveRecord::Base.connection }

  it "creates a table" do
    connection.add_column(:books, :title, :string)

    connection.create_history_table(:users) do |t|
      t.string :name
    end

    expect(connection.table_exists?(:users)).to be true
  end
end
