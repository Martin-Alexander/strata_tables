require "rails_helper"

RSpec.describe "Dummy app" do
  let(:connection) { ActiveRecord::Base.connection }

  it "creates a table" do
    connection.create_history_table(:books) do |t|
      t.string :title
    end

    expect(connection.table_exists?(:books)).to be true
  end
end
