import SFML: draw, clear, display

export render_text, d_str, draw, clear

function render_text(str,x=0,y=0;swidth=1024,sheight=768)
  t = RenderText(str)
  set_position(t,Vector2f(swidth*(0.5+x/2)-get_localbounds(t).width/2,
                          sheight*(0.5-y/2)-get_localbounds(t).height/2))
  t
end

function SFML.draw(window::RenderWindow,str::String)
  size = get_size(window)
  draw(window,render_text(str,swidth=size.x,sheight=size.y))
end

function SFML.draw(x)
  SFML.draw(get_experiment().window,x)
end

function clear()
  clear(get_experiment().window,SFML.black)
end

function display()
  display(get_experiment().window)
end

function display_text(str::String)
  clear()
  draw(str)
  display()
end
