# rubocop:disable Layout/SpaceAroundOperators

require "spec_helper"

RSpec.describe ApplicationVersioning do
  before do
    conn.enable_extension(:btree_gist)

    conn.create_table :users, primary_key: [:id, :version] do |t|
      t.bigserial :id, null: false
      t.bigint :version, null: false, default: 1
      t.tstzrange :validity, null: false
      t.string :name
      t.exclusion_constraint "id WITH =, validity WITH &&", using: :gist
    end

    conn.create_table :tasks, primary_key: [:id, :version] do |t|
      t.bigserial :id, null: false
      t.bigint :version, null: false, default: 1
      t.tstzrange :validity, null: false
      t.string :name
      t.boolean :done
      t.references :user
      t.exclusion_constraint "id WITH =, validity WITH &&", using: :gist
    end

    model "ApplicationRecord" do
      self.abstract_class = true

      include ApplicationVersioning

      set_time_dimensions :validity
    end

    model "User", ApplicationRecord do
      has_many :tasks, temporal: true
    end

    model "Task", ApplicationRecord do
      belongs_to :user, temporal: true
    end
  end

  after { drop_all_tables }

  t = Time.utc(2000)

  around do |example|
    travel_to(t, &example)
  end

  let(:user) { User.create!(id_value: 1, name: "Bob", validity: t-1...nil) }

  describe "#revise_at" do
    it "creates a revision at the given time" do
      new_user, old_user = user.revise_at(t+1).with(name: "Sam")

      expect(User.count).to eq(2)

      expect(old_user).to have_attributes(
        id_value: 1,
        name: "Bob",
        version: 1,
        validity: t-1...t+1
      )
      expect(new_user).to have_attributes(
        id_value: 1,
        name: "Sam",
        version: 2,
        validity: t+1...nil
      )
    end
  end

  describe "#revise" do
    it "creates a revision at the current time" do
      new_user, old_user = user.revise.with(name: "Sam")

      expect(old_user).to have_attributes(
        id_value: 1,
        name: "Bob",
        version: 1,
        validity: t-1...Time.current
      )
      expect(new_user).to have_attributes(
        id_value: 1,
        name: "Sam",
        version: 2,
        validity: Time.current...nil
      )
    end

    it "it creates a revision at the ambient time if set" do
      new_user, old_user = nil

      AsOfQuery::ScopeRegistry.at_time({validity: t+1}) do
        new_user, old_user = user.revise.with(name: "Sam")
      end

      expect(old_user).to have_attributes(validity: t-1...t+1)
      expect(new_user).to have_attributes(validity: t+1...nil)
    end
  end

  describe "#revision_at" do
    it "initializes a revision at the given time" do
      new_user, old_user = user.revision_at(t+1).with(name: "Sam")

      expect(old_user.changes).to eq("validity" => [t-1...nil, t-1...t+1])
      expect(new_user).to_not be_persisted
      expect(new_user).to have_attributes(
        id_value: 1,
        name: "Sam",
        version: 2,
        validity: t+1...nil
      )
    end
  end

  describe "#revision" do
    it "initializes a revision at the current time" do
      new_user, old_user = user.revision.with(name: "Sam")

      expect(old_user.changes).to eq("validity" => [t-1...nil, t-1...Time.current])
      expect(new_user).to_not be_persisted
      expect(new_user).to have_attributes(
        id_value: 1,
        name: "Sam",
        version: 2,
        validity: Time.current...nil
      )
    end

    it "it initializes a revision at the ambient time if set" do
      new_user, old_user = nil

      AsOfQuery::ScopeRegistry.at_time({validity: t+1}) do
        new_user, old_user = user.revision.with(name: "Sam")
      end

      expect(old_user).to have_attributes(validity: t-1...t+1)
      expect(new_user).to have_attributes(validity: t+1...nil)
    end
  end

  describe "#inactivate_at" do
    it "inactivates a record at a given time" do
      expect { user.inactivate_at(t+2) }
        .to(change { user.reload.validity }.from(t-1...nil).to(t-1...t+2))
    end
  end

  describe "#inactivate" do
    it "inactivates a record at a current time" do
      user.inactivate

      expect(user.reload.validity).to eq(t-1...t)
    end

    it "inactivates a record at the ambient time if set" do
      AsOfQuery::ScopeRegistry.at_time({validity: t+1}) do
        user.inactivate

        expect(user.reload.validity).to eq(t-1...t+1)
      end
    end
  end
end

# rubocop:enable Layout/SpaceAroundOperators
