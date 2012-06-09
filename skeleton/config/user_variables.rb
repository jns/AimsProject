
#
# Put user defined variables here
# These variables will be evaulated and used when
# generating geometry.in and control.in for calculations.
#
# 
#
# An example usage is 
#   
#   @lattice_const = 5.9
#   @k_grid = "2 2 2"
#
#
# Then include these in any geometry file using embedded ruby
#
#   lattice_vector <%= [@lattice_const/2, @lattice_const/2, 0].join(" ") %>
#   lattice_vector <%= [@lattice_const/2, 0, @lattice_const/2].join(" ") %>
#   lattice_vector <%= [0, @lattice_const/2, @lattice_const/2].join(" ") %>
#
# And in any control.in file 
#
#   k_grid <%= @k_grid %>
#
# The <%=  %> start and end tags can contain any ruby code
# Use <% %> start and end tags for ruby code whose output should be suppressed
# Note the '@' at the front of all variables.  This is necessary in the user_variables file 
#
# Parameters can be specified on the command line of AimsCalc as follows:
# 
#   AimsCalc create some_geometry_file some_control_file lattice_const=5.7 k_grid="2 2 2"
#
# The root calculation directory will then have a sub directory with the calculation named
#   lattice_const=5.7,k_grid=2_2_2
# Notice that variables are concatenated with a comma and spaces are replaced with underscores. 
# Only variables specified on the command line generate calculation sub-directories.  This 
# is to enable 
