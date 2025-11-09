require "spec_helper"

RSpec.describe "application versioning" do
  before do
    conn.create_table :users, primary_key: [:id, :revision] do |t|
      t.bigint :revision, null: false, default: 1
      t.bigserial :id, null: false
      t.tstzrange :validity, null: false
      t.string :name
      t.exclusion_constraint "id WITH =, validity WITH &&", using: :gist
    end

    conn.create_table :tasks, primary_key: [:id, :revision] do |t|
      t.bigint :revision, null: false, default: 1
      t.bigserial :id, null: false
      t.tstzrange :validity, null: false
      t.string :name
      t.boolean :done
      t.references :user
      t.exclusion_constraint "id WITH =, validity WITH &&", using: :gist
    end

    model "ApplicationRecord" do
      self.abstract_class = true
    end

    model "User", ApplicationRecord do
      include StrataTables::AsOf
      include StrataTables::ApplicationVersioning

      self.default_time_dimension = :validity

      has_many :tasks, temporal_association_scope
    end

    model "Task", ApplicationRecord do
      include StrataTables::AsOf
      include StrataTables::ApplicationVersioning

      self.default_time_dimension = :validity

      belongs_to :user, temporal_association_scope
    end
  end

  after { drop_all_tables }

  t = Time.utc(2000)

  around do |example|
    travel_to(t, &example)
  end

  it "create user" do
    user = User.create!(name: "Bob", validity: t...nil)

    expect(user).to have_attributes(
      id_value: 1,
      revision: 1,
      validity: t...nil,
      name: "Bob"
    )
  end

  it "create task for given user" do
    user = User.create!(name: "Bob", validity: t...nil)

    task = Task.create!(name: "Walk dog", done: false, user: user, validity: t...nil)

    expect(task).to have_attributes(
      id_value: 1,
      revision: 1,
      validity: t...nil,
      name: "Walk dog",
      user: user
    )
  end
end
