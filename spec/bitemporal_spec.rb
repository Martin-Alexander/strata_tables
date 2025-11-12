# rubocop:disable Layout/SpaceAroundOperators

require "spec_helper"

RSpec.describe "bitemporal" do
  before do
    conn.enable_extension :btree_gist

    table :authors, primary_key: [:id, :version] do |t|
      t.bigserial :id, null: false
      t.bigint :version, null: false, default: 1
      t.string :name
      t.tstzrange :validity, null: false
    end

    table :authors_history, primary_key: [:id, :version, :system_period] do |t|
      t.bigint :id, null: false
      t.bigint :version, null: false
      t.string :name
      t.tstzrange :validity, null: false
      t.tstzrange :system_period, null: false
    end

    conn.create_versioning_hook :authors, :authors_history, columns: [:id, :version, :name, :validity], primary_key: [:id, :version]

    stub_const("Version", Module.new do
      include SystemVersioning::Namespace
    end)

    model "ApplicationRecord" do
      self.abstract_class = true

      include SystemVersioning
      include ApplicationVersioning

      system_versioning

      set_time_dimensions :validity
    end

    model "Author", ApplicationRecord
  end

  after do
    drop_all_tables
    drop_all_versioning_hooks
  end

  t = Time.utc(2000)

  it "version models have both time dimensions" do
    expect(Version::Author.time_dimensions)
      .to contain_exactly(:system_period, :validity)
  end

  it "as of queries work across both time dimensions" do
    trx_1 = transaction_time { Author.create!(validity: t...) }
    trx_2 = transaction_time { Author.sole.update!(validity: t+1...) }

    expect(Version::Author.as_of(validity: t, system_period: trx_2))
      .to be_empty

    expect(Version::Author.as_of(validity: t, system_period: trx_1))
      .to_not be_empty
  end
end

# rubocop:enable Layout/SpaceAroundOperators
