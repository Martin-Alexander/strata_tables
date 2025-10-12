require "rspec/expectations"

RSpec::Matchers.define :have_loaded do |assoc|
  match do |record|
    record.association(assoc).loaded?
  end

  failure_message do |record|
    "expected #{record.inspect} to have :#{assoc} loaded"
  end
end
