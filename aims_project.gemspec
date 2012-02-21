Gem::Specification.new do |s|
  s.author = "Joshua Shapiro"
  s.email = "joshua.shapiro@gmail.com"
  s.description = "Tool for building and visualizing Aims geometry, control and output files"
  s.files = Dir.glob("{bin,lib}/**/*.rb") + Dir.glob("lib/**/*.{gif,jpg}") + %w(README) 
  s.name = "aims_project"
  s.require_paths = ["lib"]
  s.summary =<<-EOF
  This gem offers support for visualizing geometry and control files, 
  and parsing output files for the FHI-AIMS DFT code.
EOF
  s.version = "0.1.0"
  s.executables = ["AimsProjectManager"]
  s.required_ruby_version = 1.9.2
  s.add_dependency "wxruby-ruby19", "~> 2.0.1"
  s.add_dependency "ruby-opengl2", "~> 0.60.3"
  s.add_dependency "aims", "~> 0.1.0"
end
