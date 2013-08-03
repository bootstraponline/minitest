require 'tempfile'
require 'stringio'

# Disable fail on first failure
class Minitest::Runnable
  def self.check_failures result, reporter
  end
end

# Disable source rewriting
module Minitest
  def self._rewrite_source lines
    lines
  end
end

# Restore summary reporter's output
class Minitest::SummaryReporter < Minitest::StatisticsReporter
    def start # :nodoc:
      super

      io.puts "Run options: #{options[:args]}"
      io.puts
      io.puts "# Running:"
      io.puts

      self.sync = io.respond_to? :"sync=" # stupid emacs
      self.old_sync, io.sync = io.sync, true if self.sync
    end
end

require 'minitest/autorun'

class Minitest::Test
  def clean s
    s.gsub(/^ {6}/, '')
  end
end

class MetaMetaMetaTestCase < Minitest::Test
  attr_accessor :reporter, :output, :tu

  def run_tu_with_fresh_reporter flags = %w[--seed 42]
    options = Minitest.process_args flags

    @output = StringIO.new("")

    self.reporter = Minitest::CompositeReporter.new
    reporter << Minitest::SummaryReporter.new(@output, options)
    reporter << Minitest::ProgressReporter.new(@output, options)

    reporter.start

    @tus ||= [@tu]
    @tus.each do |tu|
      Minitest::Runnable.runnables.delete tu

      tu.run reporter, options
    end

    reporter.report
  end

  def first_reporter
    reporter.reporters.first
  end

  def assert_report expected, flags = %w[--seed 42]
    header = clean <<-EOM
      Run options: #{flags.map { |s| s =~ /\|/ ? s.inspect : s }.join " "}

      # Running:

    EOM

    run_tu_with_fresh_reporter flags

    output = normalize_output @output.string.dup

    assert_equal header + expected, output
  end

  def normalize_output output
    output.sub!(/Finished in .*/, "Finished in 0.00")
    output.sub!(/Loaded suite .*/, 'Loaded suite blah')

    output.gsub!(/ = \d+.\d\d s = /, ' = 0.00 s = ')
    output.gsub!(/0x[A-Fa-f0-9]+/, '0xXXX')

    if windows? then
      output.gsub!(/\[(?:[A-Za-z]:)?[^\]:]+:\d+\]/, '[FILE:LINE]')
      output.gsub!(/^(\s+)(?:[A-Za-z]:)?[^:]+:\d+:in/, '\1FILE:LINE:in')
    else
      output.gsub!(/\[[^\]:]+:\d+\]/, '[FILE:LINE]')
      output.gsub!(/^(\s+)[^:]+:\d+:in/, '\1FILE:LINE:in')
    end

    output
  end

  def setup
    super
    srand 42
    Minitest::Test.reset
    @tu = nil
  end
end
