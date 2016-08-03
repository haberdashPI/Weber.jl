push!(LOAD_PATH,pwd())
import Settings

child = @Settings.settings begin
  :list => [1,2,parent()...]
  :list2 => [0,0,parent(:list)...]
end

parent = @Settings.settings begin
  :list => [3,4]
  :list2 => [10,9]
end

x = Settings.inherits(child,parent)
x[:list]
x[:list2]
child[:list]

bill = @Settings.settings begin
  :value => (println("HI!"); 10)
  :fun => x -> x + :value
end

exp = Settings.parsesettings(:(begin
           :list => [1, 2, parent()...]
       end))
