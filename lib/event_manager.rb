require 'csv'
require 'google/apis/civicinfo_v2'
require 'erb'
require 'date'

puts 'Event Manager Initialized!'
small_file_name = 'event_attendees.csv'

def clean_zipcode(zipcode)
  zipcode.to_s.rjust(5, '0')[0..4]
end

def clean_phone_number(phone_number)
  bad_phonenumber = '0000000000'
  phone_number = phone_number.gsub(/[^0-9]/, '')

  case phone_number.size
  when 10
    phone_number
  when 11
    if phone_number[0] == '1'
      phone_number[1..]
    else
      bad_phonenumber
    end
  else
    bad_phonenumber
  end
end

def legislators_by_zipcode(zipcode)
  civic_info = Google::Apis::CivicinfoV2::CivicInfoService.new
  civic_info.key = 'AIzaSyClRzDqDh5MsXwnCWi0kOiiBivP6JsSyBw'

  begin
    civic_info.representative_info_by_address(
      address: zipcode,
      levels: 'country',
      roles: %w[legislatorUpperBody legislatorLowerBody]
    ).officials
  rescue StandardError
    'You can find your representatives by visiting www.commoncause.org/take-action/find-elected-officials'
  end
end

def save_thank_you_letter(id, form_letter)
  Dir.mkdir('output') unless Dir.exist?('output')
  filename = "output/thanks_#{id}.html"

  File.open(filename, 'w') do |file|
    file.puts form_letter
  end
  puts "Created #{filename}"
end

def highest_frequency_target(frequency_hash)
  max = frequency_hash.values.max
  highest_target = frequency_hash.select { |_k, freq| freq == max }
  highest_target.keys.join(' and ')
end

contents = CSV.open(
  small_file_name,
  headers: true,
  header_converters: :symbol
)

template_letter = File.read('form_letter.erb')
erb_template = ERB.new(template_letter)

form_submision_hour_distribution = Hash.new(0)
form_submision_wday_distribution = Hash.new(0)

contents.each do |row|
  id = row[0]
  name = row[:first_name]
  zipcode = clean_zipcode(row[:zipcode])
  phone_number = clean_phone_number(row[:homephone])
  registration_time = Time.strptime(row[:regdate], '%m/%d/%y %H:%M')

  registration_hour = registration_time.hour
  registration_wday = registration_time.wday

  form_submision_hour_distribution["#{registration_hour}h"] += 1
  form_submision_wday_distribution[Date::DAYNAMES[registration_wday]] += 1

  legislators = legislators_by_zipcode(zipcode)

  form_letter = erb_template.result(binding)

  save_thank_you_letter(id, form_letter)
  puts "The Phone number is #{phone_number}"
end

puts "The most eficient hours is:#{highest_frequency_target(form_submision_hour_distribution)}"
puts "And the week day is:#{highest_frequency_target(form_submision_wday_distribution)}"
