appraise "activerecord_edge" do
  gem "activerecord", github: "rails/rails", branch: "main"
end

%w[
  8.1.1
  8.1.0
  8.0.4
  8.0.3
  8.0.2.1
  8.0.2
  8.0.1
  8.0.0.1
  8.0.0
].each do |version|
  appraise "activerecord_#{version}" do
    gem "activerecord", version
  end
end
