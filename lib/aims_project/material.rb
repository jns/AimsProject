module AimsProject
  class Material

    include Gl

    attr_accessor :r, :g, :b, :alpha

    def Material.black
      Material.new(0,0,0)
    end

    def initialize(r,g,b,alpha=1)
      self.r = r
      self.g = g
      self.b = b
      self.alpha = alpha
    end

    def apply(lighting = true)
      if lighting
        glMaterialfv(GL_FRONT, GL_AMBIENT_AND_DIFFUSE, [self.r, self.g, self.b, self.alpha])
        glMaterialfv(GL_FRONT, GL_SPECULAR, [self.r, self.g, self.b, self.alpha])
        glMaterialf(GL_FRONT, GL_SHININESS, 50)
      else
        glColor3f(self.r, self.g, self.b)
      end
    end
  end

end