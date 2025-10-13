require "spec_helper"

RSpec.describe "version model" do
  before(:context) do
    conn.create_table(:authors) do |t|
      t.string :name
    end
    conn.create_history_table(:authors)

    randomize_sequences!(:id, :version_id)
  end

  after(:context) do
    conn.drop_table(:authors)
    conn.drop_history_table(:authors)
  end

  before do
    stub_const("ApplicationRecord", Class.new(ActiveRecord::Base) do
      self.abstract_class = true

      include StrataTables::Model
    end)
    stub_const("Author", Class.new(ApplicationRecord))
  end

  after do
    conn.truncate(:authors)
  end

  it "::as_of is delegated to ::all" do
    t_0
    bob = Author.create!(name: "Bob")
    t_1
    Author.create!(name: "Bill")
    t_2
    bob.update(name: "Bob 2")
    t_3

    expect(Author.as_of(t_0)).to be_empty
    expect(Author.as_of(t_1)).to contain_exactly(
      Author::Version.find_by!(name: "Bob")
    )
    expect(Author.as_of(t_2)).to contain_exactly(
      Author::Version.find_by!(name: "Bob"),
      Author::Version.find_by!(name: "Bill")
    )
    expect(Author.as_of(t_3)).to contain_exactly(
      Author::Version.find_by!(name: "Bill"),
      Author::Version.find_by!(name: "Bob 2")
    )
  end
end
