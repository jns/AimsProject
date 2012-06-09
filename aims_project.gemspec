Gem::Specification.new do |s|
  s.author = "Joshua Shapiro"
  s.email = "joshua.shapiro@gmail.com"
  s.description = "This gem simplifies and streamlines the calculation pipeline for FHI-AIMS."
  s.files = Dir.glob("{bin,lib}/**/*.rb") + Dir.glob("lib/**/*.{gif,jpg}") + Dir.glob("skeleton/**/*") + %w(README) 
  s.name = "aims_project"
  s.require_paths = ["lib"]
  s.summary =<<-EOF
  This gem simplifies and streamlines the calculation pipeline for FHI-AIMS.
EOF
  s.version = "0.2.0"
  s.executables = ["AimsProjectManager", "AimsCalc", "AimsProject"]
  s.required_ruby_version = "~>1.9.2"
  s.add_dependency "wxruby-ruby19", "~> 2.0.1"
  s.add_dependency "ruby-opengl2", "~> 0.60.3"
  s.add_dependency "aims", "~> 0.2.0"
  s.add_dependency "capistrano", "~> 2.11.2"
end
