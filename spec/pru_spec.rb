require 'spec_helper'
require 'tempfile'

describe Pru do
  it "has a VERSION" do
    Pru::VERSION.should =~ /^\d+\.\d+\.\d+$/
  end

  it "shows help when no arguments are given" do
    `./bin/pru`.should include('Usage:')
  end

  it 'shows -v' do
    `./bin/pru -v`.should == "#{Pru::VERSION}\n"
  end

  describe 'map' do
    it "selects" do
      `ls -l | ./bin/pru 'include?("G")'`.split("\n").size.should == 2
    end

    it "can select via regex" do
      `ls -l | ./bin/pru /G/`.split("\n").size.should == 2
    end

    it "can select via i" do
      `cat spec/test.txt | ./bin/pru 'i'`.split("\n")[0...3].should == ["1","2","3"]
    end

    it "maps" do
      `echo abc | ./bin/pru 'gsub(/a/,"b")'`.should == "bbc\n"
    end

    it "selects and reduces" do
      `cat spec/test.txt | ./bin/pru 'include?("abc")' 'size'`.should == "3\n"
    end

    it "can open files" do
      `echo spec/test.txt | ./bin/pru 'File.read(self)'`.should == File.read('spec/test.txt')
    end

    it "pipes via self" do
      `echo 'abcd' | ./bin/pru self`.should == "abcd\n"
    end

    it "pipes via ''" do
      `echo 'abcd' | ./bin/pru ''`.should == "abcd\n"
    end

    it "preserves whitespaces" do
      `echo ' ab\tcd ' | ./bin/pru self`.should == " ab\tcd \n"
    end

    it "works with continuous input" do
      results = `ruby -e 'STDOUT.sync = true; puts 1; sleep 2; puts 1' | ./bin/pru 'Time.now.to_i'`.split("\n")
      results.size.should == 2
      results.uniq.size.should == 2 # called at a different time -> parses as you go
    end

    it "can be cut off via head" do
      Tempfile.create do |e|
        Tempfile.create do |f|
          f.write "hello\n" * 10000 # need 10k for it to hit exception
          f.close
          `cat #{f.path} | ./bin/pru size 2>#{e.path} | head -1`.should == "5\n"
          $?.success?.should == true
          File.read(e).should == ""
        end
      end
    end
  end

  describe 'reduce' do
    it "reduces" do
      `cat spec/test.txt | ./bin/pru -r 'size'`.should == "5\n"
    end

    it "prints arrays as newlines" do
      `cat spec/test.txt | ./bin/pru -r 'self'`.should == File.read('spec/test.txt')
    end

    it "can sum" do
      `cat spec/test.txt | ./bin/pru -r 'sum(&:to_i)'`.should == "1212\n"
    end

    it "can mean" do
      `cat spec/test.txt | ./bin/pru -r 'mean(&:to_i)'`.should == "242.4\n"
    end

    it "can grouped" do
      `cat spec/test.txt | ./bin/pru -r 'grouped.map{|a,b| b.size }'`.should include("2\n")
    end

    it "can counted" do
      `cat spec/test.txt | ./bin/pru -r 'sort.counted'`.should == "abc : 2\n12 : 1\n1200 : 1\nabcdef : 1\n"
    end

    it "can be cut ofg via head" do
      `ls -l | ./bin/pru size 'map{|x| x > 30 ? 30 : x}' | head -n 3 2>&1`.should == "8\n30\n30\n"
      $?.success?.should == true
    end

    it "can cut big items off via head" do
      `ls -l | ./bin/pru size '"1\n" * 10' | head -n 3 2>&1`.should == "1\n1\n1\n"
      $?.success?.should == true
    end
  end

  describe 'map and reduce' do
    it "selects with empty string and reduces" do
      `cat spec/test.txt | ./bin/pru '' 'size'`.should == "5\n"
    end
  end

  describe '-I / --libdir' do
    it "adds a folder to the load-path" do
      `echo 1 | ./bin/pru -I spec --reduce 'require "a_test"; ATest.to_s'`.should == "ATest\n"
    end
  end

  describe '--require' do
    it "requires these libs" do
      `echo 1 | ./bin/pru --require rake --reduce 'Rake.to_s'`.should == "Rake\n"
    end

    it "requires these libs comma-separated" do
      `echo 1 | ./bin/pru --require bump,rake --reduce 'Rake.to_s + Bump.to_s'`.should == "RakeBump\n"
    end
  end

  describe '--inplace-edit FILE' do
    after do
      `rm -f xxx`
    end

    it "modifies the file" do
      File.open('xxx','w'){|f| f.write "abc\nab\na" }
      `./bin/pru --inplace-edit xxx size`.should == ''
      File.read('xxx').should == "3\n2\n1"
    end

    it "fails with empty file" do
      `./bin/pru --inplace-edit xxx size 2>&1`.sub(' @ rb_sysopen', '').should include('No such file or directory - xxx')
    end

    it "keeps line separators when modifying" do
      File.open('xxx','w'){|f| f.write "abc\r\nab\r\na" }
      `./bin/pru --inplace-edit xxx size`.should == ''
      File.read('xxx').should == "3\r\n2\r\n1"
    end

    it "keeps trailing lines and empty lines" do
      File.write("xxx", "\n\na\n\nb\n\n")
      `./bin/pru --inplace-edit xxx self`.should == ''
      File.read('xxx').should == "\n\na\n\nb\n\n"
    end

    it "modifies the file with reduce" do
      File.open('xxx','w'){|f| f.write "abc\nab\na" }
      `./bin/pru --inplace-edit xxx size inspect`.should == ''
      File.read('xxx').should == "[3, 2, 1]"
    end
  end
end
