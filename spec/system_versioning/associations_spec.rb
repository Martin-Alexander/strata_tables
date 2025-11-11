require "spec_helper"

RSpec.describe "system versioning associations" do
  before do
    table :libraries
    system_versioned_table :authors do |t|
      t.string :name
    end
    system_versioned_table :books do |t|
      t.references :author, foreign_key: true
      t.references :library, foreign_key: true
    end
    system_versioned_table :pics do |t|
      t.bigint :picable_id
      t.string :picable_type
    end

    stub_const("Version", Module.new do
      include SystemVersioningNamespace
    end)

    model "ApplicationRecord" do
      self.abstract_class = true

      include SystemVersioning

      system_versioning
    end
    model "Library", ApplicationRecord do
      has_many :books
      has_many :pics, as: :picable
    end
    model "Author", ApplicationRecord do
      has_many :books
      has_many :libraries, through: :books
      has_many :pics, as: :picable
    end
    model "Book", ApplicationRecord do
      belongs_to :author
      belongs_to :library
    end
    model "Pic", ApplicationRecord do
      belongs_to :picable, polymorphic: true
    end
  end

  after do
    drop_all_tables
    drop_all_versioning_hooks
  end

  shared_examples "has many" do |model_name, association, as = nil|
    poly = as ? ", as: :#{as}" : ""

    it "#{model_name}::Version has_many :#{association}#{poly}" do
      invers_assoc = as || model_name.underscore
      base_source = model_name.constantize
      base_target = association.to_s.singularize.camelize.constantize
      version_source = "Version::#{base_source.name}".constantize
      version_target = "Version::#{base_target.name}".constantize

      source_1 = base_source.create!
      source_2 = base_source.create!
      base_target.create(id_value: 1)
      base_target.create(:id_value => 2, invers_assoc => source_1)
      base_target.create(:id_value => 3, invers_assoc => source_1)
      base_target.create(:id_value => 4, invers_assoc => source_2)

      expect(version_source.first.send(association)).to contain_exactly(
        be_instance_of(version_target).and(have_attributes(id_value: 2)),
        be_instance_of(version_target).and(have_attributes(id_value: 3))
      )
    end
  end

  include_examples "has many", "Author", :books
  include_examples "has many", "Library", :books
  include_examples "has many", "Author", :pics, :picable
  include_examples "has many", "Library", :pics, :picable

  it "Version::Author has_many :libraries, through: :books" do
    author_1 = Author.create!
    author_2 = Author.create!
    library_1 = Library.create!(id_value: 1)
    library_2 = Library.create!(id_value: 2)
    library_3 = Library.create!(id_value: 3)
    Book.create
    Book.create(library: library_1)
    Book.create(author: author_2, library: library_3)
    Book.create(author: author_1)
    Book.create(author: author_1, library: library_1)
    Book.create(author: author_1, library: library_2)

    expect(Version::Author.first.libraries).to contain_exactly(
      be_instance_of(Version::Library).and(have_attributes(id_value: 1)),
      be_instance_of(Version::Library).and(have_attributes(id_value: 2))
    )
  end
end
