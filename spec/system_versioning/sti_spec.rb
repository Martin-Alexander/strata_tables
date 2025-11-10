require "spec_helper"

RSpec.describe "sti" do
  before do
    system_versioned_table :vehicles do |t|
      t.string :name
      t.string :type, :string
    end

    stub_const("Version", Module.new do
      include SystemVersioningNamespace
    end)

    model "ApplicationRecord" do
      self.abstract_class = true

      include SystemVersioning

      system_versioning
    end
    model "Vehicle", ApplicationRecord
    model "Car", Vehicle
    model "Truck", Vehicle
  end

  after do
    drop_all_tables
    drop_all_versioning_hooks
  end

  it "::instantiate returns version class for type" do
    expect(Version::Vehicle.instantiate({"type" => "Car"}).class)
      .to eq(Version::Car)

    expect(Version::Vehicle.instantiate({"type" => "Truck"}).class)
      .to eq(Version::Truck)

    expect(Version::Vehicle.find_sti_class("Car")).to eq(Version::Car)
    expect(Version::Vehicle.find_sti_class("Truck")).to eq(Version::Truck)
  end

  it "x" do
    Car.create!
    Truck.create!

    car_version = Version::Car.sole
    truck_version = Version::Truck.sole

    expect(car_version.type).to eq("Car")
    expect(truck_version.type).to eq("Truck")
  end

  it "y" do
    Car.create!(name: "Sam", type: "Car")
    Truck.create!(name: "Will", type: "Truck")

    expect(Version::Vehicle.all.count).to eq(2)
    expect(Version::Car.all.count).to eq(1)
    expect(Version::Truck.all.count).to eq(1)
  end
end
