Dir.glob("*.fnt").each do |filename|
  output = ''

  done_first = false

  font_name = filename.split('.')[0]

  output += %(
#ifndef #{font_name}_h
#define #{font_name}_h

#include <src/fonts/Font.hpp>

class #{font_name} : public Font {
  public :
    #{font_name}() {
      Log.println("  Loading '#{font_name}'");
)

  lines = File.read(filename).split("\n")
  lines.each do |line|
    if line[0]=="~"
      c = line[1]
      if done_first
        output += %{)STRLIT");
}
      end
      done_first = true
      output += %{
registerChar('#{c}', R"STRLIT(
}
    else
      output += line + "\n"
    end
  end

  output += ")STRLIT\");"

  output += %(
  }
};

#endif

)

  File.write("#{font_name}.hpp", output)

end