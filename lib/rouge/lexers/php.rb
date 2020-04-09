# -*- coding: utf-8 -*- #
# frozen_string_literal: true

module Rouge
  module Lexers
    class PHP < TemplateLexer
      title "PHP"
      desc "The PHP scripting language (php.net)"
      tag 'php'
      aliases 'php', 'php3', 'php4', 'php5'
      filenames '*.php', '*.php[345t]','*.phtml',
                # Support Drupal file extensions, see:
                # https://github.com/gitlabhq/gitlabhq/issues/8900
                '*.module', '*.inc', '*.profile', '*.install', '*.test'
      mimetypes 'text/x-php'

      option :start_inline, 'Whether to start with inline php or require <?php ... ?>. (default: best guess)'
      option :funcnamehighlighting, 'Whether to highlight builtin functions (default: true)'
      option :disabledmodules, 'Disable certain modules from being highlighted as builtins (default: empty)'

      class Stack
        def initialize
          reset
        end

        def set(stmt, default, stack = [])
          @statement = stmt
          @default = default
          @stack = stack
#           STDERR.puts "\nset: #{self.inspect}"
        end

        def none?
          @statement.nil?
        end

        def statement
          @statement
        end

        def reset
          @stack = []
          @statement = nil
          @default = Token::Tokens::Name::Other
#           STDERR.puts "\nreset: #{self.inspect}"
        end

        def push(kind)
          @stack.push(kind)
#           STDERR.puts "\npush: #{self.inspect}"
        end

        def pop
          @stack.pop || @default
#           STDERR.puts "\npop: #{self.inspect}"
        end

        def empty
          @stack.clear
#           STDERR.puts "\nempty: #{self.inspect}"
        end
      end

      def initialize(*)
        super

        @memoizer = Stack.new
        # if truthy, the lexer starts highlighting with php code
        # (no <?php required)
        @start_inline = bool_option(:start_inline) { :guess }
        @funcnamehighlighting = bool_option(:funcnamehighlighting) { true }
        @disabledmodules = list_option(:disabledmodules)
      end

      def self.builtins
        load File.join(Lexers::BASE_DIR, 'php/builtins.rb')
        self.builtins
      end

      def builtins
        return [] unless @funcnamehighlighting

        @builtins ||= Set.new.tap do |builtins|
          self.class.builtins.each do |mod, fns|
            next if @disabledmodules.include? mod
            builtins.merge(fns)
          end
        end
      end

      def reset_token
        @memoizer.reset
      end

      # source: http://php.net/manual/en/language.variables.basics.php
      # the given regex is invalid utf8, so... we're using the unicode
      # "Letter" property instead.
      id = /[\p{L}_][\p{L}\p{N}_]*/
      nsid = /#{id}(?:\\#{id})*/

      start do
        case @start_inline
        when true
          push :template
          push :php
        when false
          push :template
        when :guess
          # pass
        end
      end

      def self.keywords
        # - isset, unset and empty are actually keywords (directly handled by PHP's lexer but let's pretend these are functions, you use them like so)
        # - self and parent are kind of keywords, they are not handled by PHP's lexer
        # - use, const, namespace and function are handled by specific rules to highlight what's next to the keyword
        @keywords ||= Set.new %w(
          old_function cfunction
          __class__ __dir__ __file__ __function__ __halt_compiler __line__
          __method__ __namespace__ __trait__ abstract and array as break
          case catch clone continue declare default die do echo else
          elseif enddeclare endfor endforeach endif endswitch endwhile eval
          exit extends final finally fn for foreach global goto if implements
          include include_once instanceof insteadof list new or parent print
          private protected public require require_once return self static
          switch throw try var while xor yield
        )
      end

      def self.namespaces
        @namespaces ||= Set.new %w(namespace use)
      end

      def self.declarations
        @declarations ||= Set.new %w(class interface trait)
      end

      def self.detect?(text)
        return true if text.shebang?('php')
        return false if /^<\?hh/ =~ text
        return true if /^<\?php/ =~ text
      end

      state :root do
        # some extremely rough heuristics to decide whether to start inline or not
        rule(/\s*(?=<)/m) { delegate parent; push :template }
        rule(/[^$]+(?=<\?(php|=))/i) { delegate parent; push :template }

        rule(//) { push :template; push :php }
      end

      state :template do
        rule %r/<\?(php|=)?/i, Comment::Preproc, :php
        rule(/.*?(?=<\?)|.*/m) { delegate parent }
      end

      state :php do
        rule %r/\?>/ do
          @memoizer.reset
          token Comment::Preproc
          pop!
        end

        # heredocs
        rule %r/<<<(["']?)(#{id})\1\n.*?\n\s*\2;?/im, Str::Heredoc

        # whitespace and comments
        rule %r/\s+/, Text
        rule %r/#.*?$/, Comment::Single
        rule %r(//.*?$), Comment::Single
        rule %r(/\*\*(?!/).*?\*/)m, Comment::Doc
        rule %r(/\*.*?\*/)m, Comment::Multiline

        rule %r/(->|::)(\s*)(#{id})/ do
          groups Operator, Text, Name::Attribute
        end

        rule %r/(void|\??(int|float|bool|string|iterable|self|callable))\b/i, Keyword::Type

        rule %r/=/ do
          token Operator
          # on argument list, on '=' you pass default values, names are constants
          @memoizer.pop if :function == @memoizer.statement
        end

        # handle/exclude the "\{" first (grouped-use statement, eg: `use some\namespace\{ ... };`)
        #rule %r/\\{/, Punctuation
        rule %r/(\\)({)/ do
          groups Name::Namespace, Punctuation
        end
        rule %r/[;{]/ do
          token Punctuation
          @memoizer.reset
        end
        rule %r/,/ do
          token Punctuation
          @memoizer.empty
          # the next "direct" name might be a class name (typehinting for argument)
          @memoizer.push(Name::Class) if :function == @memoizer.statement
        end
        rule %r/\(/ do
          token Punctuation
          # drop Name::Function in case of an anonymous function
          @memoizer.pop if :function == @memoizer.statement
          # the next "direct" name might be a class name (typehinting for argument)
          @memoizer.push(Name::Class) if :function == @memoizer.statement
        end
        rule %r/\)/ do
          token Punctuation
          # the next "direct" name might be a class name (typehinting for return value)
          @memoizer.push(Name::Class) if :function == @memoizer.statement
        end
        rule %r/[\[\]}]/, Punctuation

        rule %r/stdClass\b/i, Name::Class
        rule %r/(true|false|null)\b/i, Keyword::Constant
        rule %r/(E|PHP)(_[[:upper:]]+)+\b/, Keyword::Constant
        rule %r/\$\{\$+#{id}\}/, Name::Variable
        rule %r/\$+#{id}/, Name::Variable
        rule %r/(yield)([ \n\r\t]+)(from)/i do
          groups Keyword, Text, Keyword
        end

        rule %r/[\\?]?#{nsid}/ do |m|
          name = m[0].downcase

          #STDERR.puts @memoizer.inspect
          kind = if 'use' == name
            @memoizer.set(:use, Name::Namespace)
            Keyword::Namespace
#           elsif 'as' == name
#             @memoizer.push(Name::Alias) if :use == @memoizer.statement
#             Keyword
          elsif 'class' == name
            @memoizer.set(:class, Name::Class)
            Keyword::Declaration
          elsif 'const' == name
            # distinguish 'const' found in a `use` statement
            if @memoizer.none?
              @memoizer.set(:const, Name::Constant)
            else
              @memoizer.push(Name::Constant)
            end
            Keyword
          elsif 'function' == name
            # distinguish 'function' found in a `use` statement
            if @memoizer.none?
              @memoizer.set(:function, Name::Constant, [Name::Function])
            else
              @memoizer.push(Name::Function)
            end
            Keyword
          elsif self.class.namespaces.include? name
            Keyword::Namespace
          elsif self.class.declarations.include? name
            Keyword::Declaration
          elsif self.class.keywords.include? name
            Keyword
          elsif @memoizer.none? and self.builtins.include? name
            Name::Builtin
          else
            @memoizer.pop
          end

          token kind
        end

        rule %r/[~!%^&*+\|:.<>\/@-]+/, Operator
        rule %r/\?/, Operator

        rule %r/(\d[_\d]*)?\.(\d[_\d]*)?(e[+-]?\d[_\d]*)?/i, Num::Float
        rule %r/0[0-7][0-7_]*/, Num::Oct
        rule %r/0b[01][01_]*/i, Num::Bin
        rule %r/0x[a-f0-9][a-f0-9_]*/i, Num::Hex
        rule %r/\d[_\d]*/, Num::Integer

        rule %r/'([^'\\]*(?:\\.[^'\\]*)*)'/, Str::Single
        rule %r/`([^`\\]*(?:\\.[^`\\]*)*)`/, Str::Backtick
        rule %r/"/, Str::Double, :string
      end

      state :string do
        rule %r/"/, Str::Double, :pop!
        rule %r/[^\\{$"]+/, Str::Double
        rule %r/\\u\{[0-9a-fA-F]+\}/, Str::Escape
        rule %r/\\([efrntv\"$\\]|[0-7]{1,3}|[xX][0-9a-fA-F]{1,2})/,
          Str::Escape
        rule %r/\$#{id}(\[\S+\]|->#{id})?/, Name::Variable

        rule %r/\{\$\{/, Str::Interpol, :interp_double
        rule %r/\{(?=\$)/, Str::Interpol, :interp_single
        rule %r/(\{)(\S+)(\})/ do
          groups Str::Interpol, Name::Variable, Str::Interpol
        end

        rule %r/[${\\]+/, Str::Double
      end

      state :interp_double do
        rule %r/\}\}/, Str::Interpol, :pop!
        mixin :php
      end

      state :interp_single do
        rule %r/\}/, Str::Interpol, :pop!
        mixin :php
      end
    end
  end
end
