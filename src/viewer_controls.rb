class ViewerControls

  attr_accessor :viewer

  def command_for_key(key)

    unless key.is_a? Fixnum
      key = key[0]
    end

    case key
    when ?1
      :top_view
    when ?2
      :bottom_view
    when ?3
      :west_view
    when ?4
      :east_view
    when ?5
      :north_view
    when ?6 
      :south_view
    when ?a
      :move_clip_plane
    when ?r
      :rotate
    when ?z
      :zoom
    when ?p
      :pan
    when ?o
      :ortho_view
    when ?q
      :quit
    when ?d
      :delete_atom
    when ?g
      :dump_geometry
    when ?l
      :toggle_lighting
    when ?b
      :toggle_show_bonds
    else
      puts "Unrecognized key #{key}"
      nil
    end
  end
end
