require "spec_helper"

RSpec.describe "Version" do
  after do
    DatabaseCleaner.clean_with :truncation
  end

  describe "associations" do
    let(:product_versions) { Product::Version.order(:validity) }
    let(:category_versions) { Category::Version.order(:validity) }

    describe "belongs_to" do
      it "returns the associated record at the given time" do
        category = Category.create(name: "Toys")
        product = Product.create(name: "Lego", price: 100)

        t1 = Time.now

        product.update(category: category)

        t2 = Time.now

        category.update(name: "Toys of Kids")

        t3 = Time.now

        expect(product_versions.first.category_at(t1))
          .to be_nil
        expect(product_versions.last.category_at(t2))
          .to be_a(Category::Version)
          .and have_attributes(name: "Toys")
        expect(product_versions.last.category_at(t3))
          .to be_a(Category::Version)
          .and have_attributes(name: "Toys of Kids")

        debugger
      end

      context "when given a time outside the validity range" do
        it "raises an error" do
          t0 = Time.now

          category = Category.create(name: "Toys")
          product = Product.create(name: "Lego", price: 100, category: category)

          t1 = Time.now

          product.update(name: "Lego Set")

          t2 = Time.now

          expect { product_versions.first.category_at(t0) }
            .to raise_error(ArgumentError, "outside the validity range")

          expect { product_versions.first.category_at(t2) }
            .to raise_error(ArgumentError, "outside the validity range")

          expect(product_versions.first.category_at(t1))
            .to be_a(Category::Version)
            .and have_attributes(name: "Toys")
        end
      end
    end

    describe "has_many" do
      it "returns the associated records at the given time" do
        category = Category.create(name: "Toys")

        t1 = Time.now

        Product.create(name: "Lego", category: category, price: 100)

        t2 = Time.now

        Product.create(name: "Barbie", category: category, price: 100)

        t3 = Time.now

        Product.create(name: "Hot Wheels", category: category, price: 100)

        t4 = Time.now

        expect(category_versions.first.products_at(t1))
          .to be_an(ActiveRecord::Relation)
          .and have_attributes(count: 0)

        expect(category_versions.first.products_at(t2))
          .to be_an(ActiveRecord::Relation)
          .and have_attributes(count: 1)
          .and all(have_attributes(name: "Lego"))

        expect(category_versions.first.products_at(t3))
          .to be_an(ActiveRecord::Relation)
          .and have_attributes(count: 2)
          .and include(have_attributes(name: "Lego")).exactly(1).times
          .and include(have_attributes(name: "Barbie")).exactly(1).times

        expect(category_versions.first.products_at(t4))
          .to be_an(ActiveRecord::Relation)
          .and have_attributes(count: 3)
          .and include(have_attributes(name: "Lego")).exactly(1).times
          .and include(have_attributes(name: "Barbie")).exactly(1).times
          .and include(have_attributes(name: "Hot Wheels")).exactly(1).times
      end

      context "when given a time outside the validity range" do
        it "raises an error" do
          t0 = Time.now

          category = Category.create(name: "Toys")

          t1 = Time.now

          Product.create(name: "Lego", category: category, price: 100)

          t2 = Time.now

          category.update(name: "Toys of Kids")

          t3 = Time.now

          expect { category_versions.first.products_at(t0) }
            .to raise_error(ArgumentError, "outside the validity range")

          expect(category_versions.first.products_at(t1))
            .to be_an(ActiveRecord::Relation)
            .and have_attributes(count: 0)

          expect(category_versions.first.products_at(t2))
            .to be_an(ActiveRecord::Relation)
            .and have_attributes(count: 1)
            .and include(have_attributes(name: "Lego"))

          expect { category_versions.first.products_at(t3) }
            .to raise_error(ArgumentError, "outside the validity range")
        end
      end
    end
  end
end
