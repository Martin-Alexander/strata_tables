%w[
  8.0.3
  8.0.2.1
  8.0.2
  8.0.1
  8.0.0.1
  8.0.0
  7.2.2.2
  7.2.2.1
  7.2.2
  7.2.1.2
  7.2.1.1
  7.2.1
  7.2.0
].each do |version|
  appraise "ar-#{version.gsub(".", "_")}" do
    gem "activerecord", version
  end
end

appraise "ar-edge" do
  gem "activesupport", github: "rails/rails", branch: "main"
  gem "activemodel", github: "rails/rails", branch: "main"
  gem "activerecord", github: "rails/rails", branch: "main"
  gem "pg"
end
