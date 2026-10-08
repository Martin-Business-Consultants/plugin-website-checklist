require_relative "lib/website_checklist/version"

# The gemspec's name is the plugin's key and its table prefix.
Gem::Specification.new do |spec|
  spec.name = "website_checklist"
  spec.version = WebsiteChecklist::VERSION
  spec.summary = "Website checklist for Runwell: every client website's setup, recorded and confirmed, as the source of truth"
  spec.authors = [ "Martin Business Consultants" ]
  spec.homepage = "https://github.com/Martin-Business-Consultants/runwell-website-checklist"
  spec.license = "FSL-1.1-MIT"
  spec.files = Dir["{app,config,db,lib}/**/*"]
  spec.required_ruby_version = ">= 3.3"
  spec.add_dependency "rails", ">= 8.1"
end
