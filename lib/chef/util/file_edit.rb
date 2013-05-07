#
# Author:: Nuo Yan (<nuo@opscode.com>)
# Copyright:: Copyright (c) 2009 Opscode, Inc.
# License:: Apache License, Version 2.0
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

require 'fileutils'
require 'tempfile'

class Chef
  class Util
    class FileEdit

      private

      attr_accessor :original_pathname, :contents, :file_edited

      public

      def initialize(filepath)
        @original_pathname = filepath
        @file_edited = false

        raise ArgumentError, "File doesn't exist" unless File.exist? @original_pathname
        raise ArgumentError, "File is blank" unless (@contents = File.new(@original_pathname).readlines).length > 0
      end

      #search the file line by line and match each line with the given regex
      #if matched, replace the whole line with newline.
      def search_file_replace_line(regex, newline)
        search_match(regex, newline, :replace, :full_line)
      end

      #search the file line by line and match each line with the given regex
      #if matched, replace the match (all occurances)  with the replace parameter
      def search_file_replace(regex, replace)
        search_match(regex, replace, :replace, :partial_line)
      end

      #search the file line by line and match each line with the given regex
      #if matched, delete the line
      def search_file_delete_line(regex)
        search_match(regex, " ", :delete, :full_line)
      end

      #search the file line by line and match each line with the given regex
      #if matched, delete the match (all occurances) from the line
      def search_file_delete(regex)
        search_match(regex, " ", :delete, :partial_line)
      end

      #search the file line by line and match each line with the given regex
      #if matched, insert newline after each matching line
      def insert_line_after_match(regex, newline)
        search_match(regex, newline, :insert, :after_match)
      end

      #search the file line by line and match each line with the given regex
      #if not matched, insert newline at the end of the file
      def insert_line_if_no_match(regex, newline)
        search_match(regex, newline, :insert, :if_no_match)
      end

      #Make a copy of old_file and write new file out (only if file changed)
      def write_file

        # file_edited is false when there was no match in the whole file and thus no contents have changed.
        if file_edited
          backup_pathname = original_pathname + ".old"
          FileUtils.cp(original_pathname, backup_pathname, :preserve => true)
          File.open(original_pathname, "w") do |newfile|
            contents.each do |line|
              newfile.puts(line)
            end
            newfile.flush
          end
        end
        self.file_edited = false
      end

      private

      #helper method to do the match, replace, delete, and insert operations
      #command is the switch of delete, replace, and insert (:delete, :replace, :insert)
      #method is to control operation on whole line or only the match (:full_line for line, :partial_line for match)
      # or, for insert, whether it's done after the match or if no match is found (:after_match, :if_no_match)
      def search_match(regex, replacement, command, method)

        #convert regex to a Regexp object (if not already is one) and store it in exp.
        exp = Regexp.new(regex)

        #loop through contents and do the appropriate operation depending on 'command' and 'method'
        new_contents = []

        match_found = false

        contents.each do |line|
          if line.match(exp)
            match_found = true
            case command
            when :replace
              new_contents << ((method == :full_line) ? replacement : line.gsub!(exp, replacement))
            when :delete
              new_contents << line.gsub!(exp, "") if method == :partial_line
            when :insert
              new_contents << line
              new_contents << replace if method == :after_match
            end
          else
            new_contents << line
          end
        end
        self.file_edited = true if match_found

        if command == :insert && method == :if_no_match && ! match_found
          new_contents << replace
          self.file_edited = true
        end

        self.contents = new_contents
      end
    end
  end
end
