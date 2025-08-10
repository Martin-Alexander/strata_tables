require "spec_helper"

RSpec.describe "an expand contract flow" do
  before do
    conn.create_strata_table(:users)
  end

  after do
    DatabaseCleaner.clean_with :truncation
    conn.drop_strata_table(:users)
    conn.remove_column(:users, :full_name, if_exists: true)
    conn.add_column(:users, :first_name, :string, null: false, if_not_exists: true)
    conn.add_column(:users, :last_name, :string, null: false, if_not_exists: true)
  end

  let(:strata_user_class) do
    Class.new(ActiveRecord::Base) do
      def self.model_name
        ActiveModel::Name.new(self, nil, "StrataUser")
      end
    end
  end

  it "records the expected history" do
    insert_time = transaction_with_time(conn) do
      User.create!(first_name: "Jane", last_name: "Austen")
      User.create!(first_name: "Nathaniel", last_name: "Hawthorne")
    end

    jane = User.find_by(first_name: "Jane")
    nathaniel = User.find_by(first_name: "Nathaniel")

    # Expand
    conn.add_column(:users, :full_name, :string)
    conn.add_strata_column(:users, :full_name, :string)

    User.reset_column_information
    strata_user_class.reset_column_information

    # Writes duplicated
    update_time = transaction_with_time(conn) do
      jane.reload.update!(full_name: "Jane Doe", first_name: "Jane", last_name: "Doe")
    end

    # Data migration
    data_migration_time = transaction_with_time(conn) do
      conn.execute("UPDATE users SET full_name = CONCAT(first_name, ' ', last_name)")
    end

    # Reads moved to new column, old schema deprecated,writes no longer duplicated
    post_data_migration_time = transaction_with_time(conn) do
      nathaniel.reload.update!(full_name: "Nathaniel Hawthorne")
    end

    # Finale schema migration
    data_schema_migration_time = transaction_with_time(conn) do
      conn.remove_column(:users, :first_name)
      conn.remove_column(:users, :last_name)

      conn.remove_strata_column(:users, :first_name)
      conn.remove_strata_column(:users, :last_name)
    end

    strata_users = strata_user_class.where(id: jane.id).order(validity: :desc)

    byebug

    expect(strata_users.count).to eq(3)

    StrataTables.as_of(10.days.ago) do
      
    end
  end
end
