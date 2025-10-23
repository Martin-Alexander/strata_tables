require "spec_helper"

RSpec.describe "version model" do
  before(:context) do
    conn.create_table(:authors) do |t|
      t.string :name
      t.string :type, :string
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
    stub_const("FictionAuthor", Class.new(Author))
    stub_const("NonFictionAuthor", Class.new(Author))
  end

  after do
    conn.truncate(:authors)
    conn.truncate(:authors_history)
  end

  it "::instantiate returns version class for type" do
    expect(Author.version.instantiate({"type" => "NonFictionAuthor"}).class)
      .to eq(NonFictionAuthor.version)

    expect(Author.version.instantiate({"type" => "FictionAuthor"}).class)
      .to eq(FictionAuthor.version)

    expect(Author.version.find_sti_class("NonFictionAuthor")).to eq(NonFictionAuthor.version)
    expect(Author.version.find_sti_class("FictionAuthor")).to eq(FictionAuthor.version)
  end

  it do
    fiction_author_version = FictionAuthor.version.create!(id_value: 1, sys_period: nil...nil)
    non_fiction_author_version = NonFictionAuthor.version.create!(id_value: 2, sys_period: nil...nil)

    expect(fiction_author_version.type).to eq("FictionAuthor")
    expect(non_fiction_author_version.type).to eq("NonFictionAuthor")
  end

  it do
    FictionAuthor.create!(name: "Sam", type: "FictionAuthor")
    NonFictionAuthor.create!(name: "Will", type: "NonFictionAuthor")

    expect(Author.version.all.count).to eq(2)
    expect(FictionAuthor.version.all.count).to eq(1)
    expect(NonFictionAuthor.version.all.count).to eq(1)
  end
end
