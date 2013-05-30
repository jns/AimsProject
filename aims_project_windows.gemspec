Gem::Specification.new do |s|
  s.author = "Joshua Shapiro"
  s.email = "joshua.shapiro@gmail.com"
  s.description = "This gem simplifies and streamlines the calculation pipeline for FHI-AIMS."
  s.files = Dir.glob("{bin,lib}/**/*.rb") + Dir.glob("lib/**/*.{gif,jpg}") + Dir.glob("skeleton/**/*") + %w(README) 
  s.name = "aims_project_windows"
  s.homepage = "https://github.com/jns/AimsProject"
  s.require_paths = ["lib"]
  s.summary =<<-EOF
  This gem simplifies and streamlines the calculation pipeline for FHI-AIMS.
EOF
  s.version = "0.3.2"
  s.executables = ["AimsProjectManager", "AimsCalc", "AimsProject"]
  s.required_ruby_version = "~>1.9.2"
  s.add_dependency "wxruby-ruby19", "~> 2.0.0"
  s.add_dependency "ruby-opengl", "~> 0.61.0"
  s.add_dependency "aims", "~> 0.3.0"
  s.add_dependency "highline", "~> 1.6.11"
  s.add_dependency "capistrano", "~> 2.11.2"
end
