require 'csv'
require 'pry'
require 'google/apis/civicinfo_v2'
require 'erb'
require 'time'
require 'date'

puts 'EventManager Initialized!'

file = 'event_attendees.csv'


def sanitize_zip_code(zip_code)
  zip_code.to_s.slice(0..4).rjust(5, '0')
end

def legislators_by_zip_code(zip_code)
  civic_info = Google::Apis::CivicinfoV2::CivicInfoService.new
  civic_info.key = 'AIzaSyClRzDqDh5MsXwnCWi0kOiiBivP6JsSyBw'
  
  begin
    civic_info.representative_info_by_address(
      address: zip_code, 
      levels: 'country', 
      roles: ['legislatorUpperBody', 'legislatorLowerBody']
    ).officials
  rescue
    'You can find your representatives by visiting www.commoncause.org/take-action/find-elected-officials'
  end
end

def sanitize_phone_number(phone_number)
  phone_number = remove_separators(phone_number)
  phone_number = validate_phone_number(phone_number)
end

def remove_separators(phone_number)
  phone_number.split('').select do |character| 
    character == character.to_i.to_s
  end
end

def validate_phone_number(phone_number)
  length = phone_number.length
  
  case 
  when length == 10
    phone_number.join
  when length == 11 && ['1'].include?(phone_number.first)
    phone_number.slice(1..-1).join
  else
    'Invalid phone number!'
  end
end

def convert_regdate_to_time(date_time)
  Time.strptime(date_time, "%m/%e/%y %k:%M")
end

def save_letter(id, letter_content)
  Dir.mkdir('output') unless Dir.exist?('output')
  file_path = "output/#{id}_letter.html"
  File.open(file_path, 'w') do |file|
    file.puts letter_content
  end
end

contents = CSV.open(file, headers: true, header_converters: :symbol)

template_letter = File.read('form_letter.erb')
erb_template = ERB.new(template_letter)

attendee_times = []

contents.each do |row|
  id = row[0]
  
  first_name = row[:first_name]
  
  zip_code = sanitize_zip_code(row[:zipcode])
  
  legislators = legislators_by_zip_code(zip_code)
  
  phone_number = sanitize_phone_number(row[:homephone])

  reg_date_time = convert_regdate_to_time(row[:regdate])
  attendee_times << reg_date_time
  
  personal_letter = erb_template.result(binding)
  save_letter(id, personal_letter)
end

def find_peak(times)
  frequency = times.group_by { |i| times.count(i) }
  peak = frequency.max_by { |frequency| frequency }[1].uniq
end

def convert_hours_to_time(hours)
  hours.map do |hour| 
    Time.strptime(hour.to_s, "%k").strftime("%l:%M%P")
  end
end

def convert_days_to_date(days)
  days.map do |day|
    Date::DAYNAMES[day]
  end
end

peak_hours = find_peak(attendee_times.map(&:hour))
peak_hours = convert_hours_to_time(peak_hours)
puts "The peak registration hours were#{peak_hours.join(' and')}."

peak_days = find_peak(attendee_times.map(&:wday))
peak_days = convert_days_to_date(peak_days)
puts "The peak registration days were #{peak_days.join(' and')}."
