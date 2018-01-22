#!/usr/bin/ruby

# Convert multiple vCard (.vcf) files to Yahoo CSV contacts list
# Copyright (C) 2018  Denis Yantarev <denis.yantarev@gmail.com>
#
# This program is free software: you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation, either version 3 of the License, or
# (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program.  If not, see <http://www.gnu.org/licenses/>.

require 'csv'
require 'optparse'

require 'rubygems'
require 'vcardigan'

def output_headers
  yahoo_headers = [
    'First',
    'Middle',
    'Last',
    'Nickname',
    'Email',
    'Category',
    'Distribution Lists',
    'Messenger ID',
    'Home',
    'Work',
    'Pager',
    'Fax',
    'Mobile',
    'Other',
    'Yahoo Phone',
    'Primary',
    'Alternate Email 1',
    'Alternate Email 2',
    'Personal Website',
    'Business Website',
    'Title',
    'Company',
    'Work Address',
    'Work City',
    'Work State',
    'Work ZIP',
    'Work Country',
    'Home Address',
    'Home City',
    'Home State',
    'Home ZIP',
    'Home Country',
    'Birthday',
    'Anniversary',
    'Custom 1',
    'Custom 2',
    'Custom 3',
    'Custom 4',
    'Comments',
    'Messenger ID1',
    'Messenger ID2',
    'Messenger ID3',
    'Messenger ID4',
    'Messenger ID5',
    'Messenger ID6',
    'Messenger ID7',
    'Messenger ID8',
    'Messenger ID9',
    'Skype ID',
    'IRC ID',
    'ICQ ID',
    'Google ID',
    'MSN ID',
    'AIM ID',
    'QQ ID'
  ]
  print yahoo_headers.to_csv
end

def process_file(file)
  Dir.glob(file) do |f|
    if File.file?(f)
      data = File.read(f)
      vcard = VCardigan.parse(data)
      # Workaround library bug - in fact FN is optional for vCard 2.1
      if !vcard.fullname
        vcard.n.first.values.each do |name|
          if name
            vcard.fullname name
            break
          end
        end
      end
      cell_phone = ''
      home_phone = ''
      work_phone = ''
      first_name = ''
      last_name = ''
      nickname = ''
      email = ''
      vcard.tel.each do |tel|
        if tel.params['cell'] || tel.params['type'] == 'CELL'
          cell_phone = tel.values.first
        elsif tel.params['type'] == 'WORK'
          work_phone = tel.values.first
        else
          home_phone = tel.values.first
        end
      end
      if vcard.n
        first_name = vcard.n.first.values[1].gsub('=20', ' ')
        last_name = vcard.n.first.values[0].gsub('=20', ' ')
      end
      if vcard.nickname
        nickname = vcard.nickname.first.values[0].gsub('=20', ' ')
      end
      if vcard.email
        email = vcard.email.first.values[0]
      end
      yahoo_row = [
        first_name, # First
        '', # Middle
        last_name, # Last
        nickname, # Nickname
        email, # Email
        '', # Category
        '', # Distribution Lists
        '', # Messenger ID
        home_phone, # Home
        work_phone, # Work
        '', # Pager
        '', # Fax
        cell_phone, # Mobile
        '', # Other
        '', # Yahoo Phone
        '', # Primary
        '', # Alternate Email 1
        '', # Alternate Email 2
        '', # Personal Website
        '', # Business Website
        '', # Title
        '', # Company
        '', # Work Address
        '', # Work City
        '', # Work State
        '', # Work ZIP
        '', # Work Country
        '', # Home Address
        '', # Home City
        '', # Home State
        '', # Home ZIP
        '', # Home Country
        '', # Birthday
        '', # Anniversary
        '', # Custom 1
        '', # Custom 2
        '', # Custom 3
        '', # Custom 4
        '', # Comments
        '', # Messenger ID1
        '', # Messenger ID2
        '', # Messenger ID3
        '', # Messenger ID4
        '', # Messenger ID5
        '', # Messenger ID6
        '', # Messenger ID7
        '', # Messenger ID8
        '', # Messenger ID9
        '', # Skype ID
        '', # IRC ID
        '', # ICQ ID
        '', # Google ID
        '', # MSN ID
        '', # AIM ID
        ''  # QQ ID
      ]
      puts yahoo_row.to_csv
    end
  end
end

optparser = OptionParser.new do |opts|
  opts.banner = 'Usage: vcf_to_yahoo_cvs.rb file ...'
  opts.on('-h', '--help', 'Display this screen') do
    puts opts
    exit
  end
end

optparser.parse!

output_headers
ARGV.each do |file|
  process_file(file)
end
