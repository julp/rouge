# -*- coding: utf-8 -*- #
# frozen_string_literal: true

describe Rouge::Lexers::PHP do
  let(:subject) { Rouge::Lexers::PHP.new }

  describe 'guessing' do
    include Support::Guessing

    it 'Guesses files containing <?php' do
      assert_guess :source => '<?php foo();'
    end

    it 'Guesses PHP files that do not contain Hack code' do
      assert_guess :filename => 'foo.php', :source => '<? foo();'
    end

    it 'Guesses .php files containing <?, but not hack code' do
      deny_guess :filename => 'foo.php', :source => '<?hh // strict'
    end

    it "Does not guess files containing <?hh" do
      deny_guess :source => '<?hh foo();'
      deny_guess :source => '<?hh // strict'
      deny_guess :filename => '.php', :source => '<?hh foo();'
    end
  end

  describe 'lexing' do
    include Support::Lexing

    it 'recognizes hash comments not followed by a newline (#797)' do
      assert_tokens_equal '# comment', ['Comment.Single', '# comment']
    end

    it 'recognizes double-slash comments not followed by a newline (#797)' do
      assert_tokens_equal '// comment', ['Comment.Single', '// comment']
    end
    
    it 'recognizes try catch finally definition' do
      assert_tokens_equal 'try {} catch () {} finally {}', ["Keyword", "try"], ["Text", " "], ["Punctuation", "{}"], ["Text", " "], ["Keyword", "catch"], ["Text", " "], ["Punctuation", "()"], ["Text", " "], ["Punctuation", "{}"], ["Text", " "], ["Keyword", "finally"], ["Text", " "], ["Punctuation", "{}"]
    end
    
    it 'recognizes class definition' do
      assert_tokens_equal 'class A {}', ["Keyword.Declaration", "class"], ["Text", " "], ["Name.Class", "A"], ["Text", " "], ["Punctuation", "{}"]
    end
    
    it 'recognizes interface definition' do
      assert_tokens_equal 'interface A {}', ["Keyword.Declaration", "interface"], ["Text", " "], ["Name.Class", "A"], ["Text", " "], ["Punctuation", "{}"]
    end
    
    it 'recognizes trait definition' do
      assert_tokens_equal 'trait A {}', ["Keyword.Declaration", "trait"], ["Text", " "], ["Name.Class", "A"], ["Text", " "], ["Punctuation", "{}"]
    end

    it 'lexes correctly use statements' do
      # issue #1353
      assert_tokens_equal 'Use Class1, Class2;', ['Keyword.Namespace', 'Use'], ['Text', ' '], ['Name.Namespace', 'Class1'], ['Punctuation', ','], ['Text', ' '], ['Name.Namespace', 'Class2'], ['Punctuation', ';']

      # issue #1361
      assert_tokens_equal 'Use TraitA, TraitB {', ['Keyword.Namespace', 'Use'], ['Text', ' '], ['Name.Namespace', 'TraitA'], ['Punctuation', ','], ['Text', ' '], ['Name.Namespace', 'TraitB'], ['Text', ' '], ['Punctuation', '{']

      assert_tokens_equal 'Use My\Full\Classname As Another;', ['Keyword.Namespace', 'Use'], ['Text', ' '], ['Name.Namespace', 'My\Full\Classname'], ['Text', ' '], ['Keyword', 'As'], ['Text', ' '], ['Name', 'Another'], ['Punctuation', ';']
      assert_tokens_equal 'Use My\Full\NSname;', ['Keyword.Namespace', 'Use'], ['Text', ' '], ['Name.Namespace', 'My\Full\NSname'], ['Punctuation', ';']
      assert_tokens_equal 'Use ArrayObject;', ['Keyword.Namespace', 'Use'], ['Text', ' '], ['Name.Namespace', 'ArrayObject'], ['Punctuation', ';']
      assert_tokens_equal 'Use Function My\Full\functionName;', ['Keyword.Namespace', 'Use'], ['Text', ' '], ['Keyword', 'Function'], ['Text', ' '], ['Name.Namespace', 'My\Full\functionName'], ['Punctuation', ';']
      assert_tokens_equal 'Use Function My\Full\functionName As func;', ['Keyword.Namespace', 'Use'], ['Text', ' '], ['Keyword', 'Function'], ['Text', ' '], ['Name.Namespace', 'My\Full\functionName'], ['Text', ' '], ['Keyword', 'As'], ['Text', ' '], ['Name', 'func'], ['Punctuation', ';']
      assert_tokens_equal 'Use Const My\Full\CONSTANT;', ['Keyword.Namespace', 'Use'], ['Text', ' '], ['Keyword', 'Const'], ['Text', ' '], ['Name.Namespace', 'My\Full\CONSTANT'], ['Punctuation', ';']
      assert_tokens_equal 'Use My\Full\Classname As Another, My\Full\NSname;',  ['Keyword.Namespace', 'Use'], ['Text', ' '], ['Name.Namespace', 'My\Full\Classname'], ['Text', ' '], ['Keyword', 'As'], ['Text', ' '], ['Name', 'Another'], ['Punctuation', ','], ['Text', ' '], ['Name.Namespace', 'My\Full\NSname'], ['Punctuation', ';']

      assert_tokens_equal 'Use some\name\{ClassA, ClassB, ClassC As C};', ['Keyword.Namespace', 'Use'], ['Text', ' '], ['Name.Namespace', 'some\name'], ['Operator', '\{'],
        ['Name.Namespace', 'ClassA'], ['Operator', ','],
        ['Text', ' '], ['Name.Namespace', 'ClassB'],
        ['Operator', ','], ['Text', ' '],
        ['Name.Namespace', 'ClassC'], ['Text', ' '], ['Keyword', 'As'], ['Text', ' '], ['Name', 'C'], ['Operator', '}'], ['Punctuation', ';']
      assert_tokens_equal 'Use Function some\name\{fn_a, fn_b, fn_c};', ['Keyword.Namespace', 'Use'], ['Text', ' '], ['Keyword', 'Function'], ['Text', ' '], ['Name.Namespace', 'some\name'], ['Operator', '\{'],
        ['Name.Namespace', 'fn_a'], ['Operator', ','],
        ['Text', ' '], ['Name.Namespace', 'fn_b'], ['Operator', ','],
        ['Text', ' '], ['Name.Namespace', 'fn_c'], ['Operator', '}'], ['Punctuation', ';']
      assert_tokens_equal 'Use Const some\name\{ConstA, ConstB, ConstC};', ['Keyword.Namespace', 'Use'], ['Text', ' '], ['Keyword', 'Const'], ['Text', ' '], ['Name.Namespace', 'some\name'], ['Operator', '\{'],
        ['Name.Namespace', 'ConstA'], ['Operator', ','],
        ['Text', ' '], ['Name.Namespace', 'ConstB'], ['Operator', ','], ['Text', ' '],
        ['Name.Namespace', 'ConstC'], ['Operator', '}'], ['Punctuation', ';']
      assert_tokens_equal 'Use some\name\{Function some_fn, Const Foo\BAR, SomeClass};', ['Keyword.Namespace', 'Use'], ['Text', ' '], ['Name.Namespace', 'some\name'], ['Operator', '\{'],
        ['Keyword', 'Function'], ['Text', ' '], ['Name.Namespace', 'some_fn'], ['Operator', ','],
        ['Text', ' '], ['Keyword', 'Const'], ['Text', ' '], ['Name.Namespace', 'Foo\BAR'], ['Operator', ','],
        ['Text', ' '], ['Name.Namespace', 'SomeClass'], ['Operator', '}'], ['Punctuation', ';']
    end
  end
end
