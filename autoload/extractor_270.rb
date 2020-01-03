module RubyHlLvar
  class Extractor
    def initialize(show_warning = false)
      @show_warning = show_warning
    end

    def warn(message)
      ::Vim.message "[ruby_hl_lvar.vim] WARN: #{message}" if @show_warning
    end

    # source:String -> [ [lvar_name:String, line:Numeric, col:Numeric]... ]
    def extract(source)
      sexp = Ripper.sexp(source)
      extract_from_sexp(sexp)
    end

    def extract_from_sexp(sexp)
      case sexp
      in [:assign, [:var_field, [:@ident, a,   [b, c]]], d]
        [[a, b, c]] + extract_from_sexp(d)
      in [:massign, a, b]
        # mass assignment
        handle_massign_lhs(a) + extract_from_sexp(b)
      in [:opassign, [:var_field, [:@ident, a, [b, c]]], _, d]
        # +=
        [[a, b, c]] + extract_from_sexp(d)
      in [:var_ref, [:@ident, a, [b, c]]]
        # local variable reference
        [[a, b, c]]
      in [:rescue, a, [:var_field, [:@ident, b, [c, d]]], e, f]
        # rescue
        [[b, c, d]] + extract_from_sexp(a) + extract_from_sexp(e) + extract_from_sexp(f)
      in [:params, *a]
        # method params
        handle_normal_params(a[0]) +
          handle_default_params(a[1]) +
          handle_rest_param(a[2]) +
          handle_normal_params(a[3]) +
          handle_block_param(a[6])
      in [:for, a, b, c]
        # for
        handle_for_param(a) + extract_from_sexp(b) + extract_from_sexp(c)
      else
        if sexp.is_a?(Array) && sexp.size > 0
          if sexp[0].is_a?(Symbol) # some struct
            sexp[1..-1].flat_map {|elm| extract_from_sexp(elm) }
          else
            sexp.flat_map{|elm| extract_from_sexp(elm) }
          end
        else
          warn "Unsupported AST data: #{sexp.inspect}"
          []
        end
      end
    end

    def handle_massign_lhs_item(sexp)
      case sexp
      in [:var_field, [:@ident, a, [b, c]]]
        [[a, b, c]]
      in [:@ident, a, [b, c]]
        [[a, b, c]]
      in [:mlhs, *xs]
        xs.inject([]) {|lhss, l| lhss + handle_massign_lhs(l) }
      in [:aref_field, a, b]
        extract_from_sexp(a) + extract_from_sexp(b)
      in [:field, :@ivar, :@cvar, :@gvar, :@const, xs]
        []
      in [:rest_param, a]
        handle_massign_lhs_item(a)
      in [nil]
        []
      else
        warn "Unsupported ast item in handle_massign_lhs: #{sexp.inspect}"
        []
      end
    end

    def handle_massign_lhs(lhs)
      return [] unless lhs
      if lhs.size > 0 && lhs[0].is_a?(Symbol)
        lhs = [lhs]
      end
      lhs.flat_map {|expr| handle_massign_lhs_item(expr) }
    end

    def handle_normal_params(list)
      handle_massign_lhs(list)
    end

    def handle_rest_param(sexp)
      case sexp
      in [:rest_param, [:@ident, a, [b, c]]]
        [[a, b, c]]
      in nil
        []
      in 0
        []
      in [:rest_param, nil]
        []
      else
        warn "Unsupported ast item in handle_rest_params: #{sexp.inspect}"
        []
      end
    end

    def handle_block_param(sexp)
      case sexp
      in [:blockarg, [:@ident, a, [b, c]]]
        [[a, b, c]]
      in nil
        []
      else
        warn "Unsupported ast item in handle_block_params: #{sexp.inspect}"
        []
      end
    end

    def handle_default_params(list)
      return [] unless list
      list.flat_map {|expr| handle_default_param(expr) }
    end

    def handle_default_param(sexp)
      case sexp
      in [[:@ident, a, [b, c]], *]
        [[a, b, c]]
      else
        []
      end
    end

    def handle_for_param(sexp)
      case sexp
      in [:var_field, [:@ident, a, [b, c]]]
        [[a, b, c]]
      in [:var_field, _]
        []
      else
        handle_massign_lhs(sexp)
      end
    end
  end
end
