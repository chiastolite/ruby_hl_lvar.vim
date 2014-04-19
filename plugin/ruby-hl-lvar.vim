""; <<-finish
finish

require 'ripper'

module RubyHlLvar
  class Extractor
    # source:String -> [ [lvar_name:String, line:Numeric, col:Numeric]... ]
    def extract(source)
      sexp = Ripper.sexp(source)
      extract_from_sexp(sexp)
    end

    def extract_from_sexp(sexp)
      case sexp[0]
      when :program
        sexp[1].flat_map {|part| extract_from_sexp(part)}
      when :assign
        _, lhs, rhs = sexp
        # [:var_field, [:@ident, name, [l, c]]]
        _, (_, name, (line, col)) = lhs
        [[name, line, col]]
      else
        [] # Just ignore subtree
      end
    end

  end
end

