require 'sinatra'
require 'csv'
require 'erb'
require 'sinatra/config_file'
require 'open-uri'
require 'JSON'

config_file '../config.yml'

#this method provided in tutorial
def clean_zipcode(zipcode)
  zipcode.to_s.rjust(5,"0")[0..4]
end

def clean_phonenumber(homephone)
  phonenumber = homephone.to_s.gsub(/\D/,'')
  if phonenumber[0] == '1'
    phonenumber[0] = ''
  end
  if phonenumber.length != 10
    return "bad number"
  else
    return phonenumber
  end
end

def legislators_by_zipcode(zipcode)
  response = open("https://congress.api.sunlightfoundation.com/legislators/locate?zip=#{zipcode}", "x-api-key" => settings.sunshine_api_key)
  parsed_response=JSON.parse(response.read)
  array_of_legislators = parsed_response["results"]
end

#this method provided in tutorial
def save_thank_you_letters(id,form_letter)
  Dir.mkdir("output") unless Dir.exists?("output")
  filename = "output/thanks_#{id}.html"
  File.open(filename,'w') do |file|
    file.puts form_letter
  end
end

def registration_hour_day(regdate)
  hour_day = []
  regdate = DateTime.strptime(regdate, '%m/%d/%Y %H:%M')
  hour_day << regdate.hour << regdate.wday
end

def registration_day_name(weekday)
  days_of_week = {0 => "Sunday", 1 => "Monday", 2=>"Tuesday", 3=>"Wednesday", 4=>"Thursday", 5=>"Friday", 6=>"Saturday"}
  name_day = days_of_week[weekday]
end

def active_period(span)
  span.each_with_object({}) do |hr, hsh|
    hsh[hr] ? hsh[hr] += 1 : hsh[hr] =1
  end
end

def popular_period(span)
  highest_arr =[]
  #sort array by increasing number of instances (i.e values)
  sorted_arr = span.sort_by {|first, second| second }
  #select the key-value pair with highest value
  highest = sorted_arr[-1]
  #check to see if there are other key-value pairs that have same highest value and if so create array of those pairs
  highest_arr << sorted_arr.select { |k| k[1] >= highest[1] }
  highest_arr.flatten!(1)
end

def demilitarize_hour(hours)
  if hours.length > 1
    puts "There is more than one peak hour:"
  end
  hours.each do |x|
    if x[0] > 12
      puts "Peak hour is #{x[0] -= 12} p.m."
    else
      puts "Peak hour is #{x[0]} a.m."
    end
  end
end

def show_days(peak_days)
  if peak_days.length > 1
    puts "There is more than one peak day:"
  end
  peak_days.each do |day|
      puts "Peak day is #{day[0]}"
  end
end

puts "EventManager initialized."

contents = CSV.open '../event_attendees.csv', headers: true, header_converters: :symbol

template_letter = File.read "views/form_letter.erb"
erb_template = ERB.new template_letter
tally_hours = []
tally_days = []
result = []

#for each row in the spreadsheet . . .
contents.each do |row|
  id = row[0]
  name = row[:first_name]

  # . . . standardize the zip code
  zipcode = clean_zipcode(row[:zipcode])

  # . . . standardize the phone number
  phone_number = clean_phonenumber(row[:homephone])
  
  # . . . look up the legislator(s) for that zip code
  legislators = legislators_by_zipcode(zipcode)

  # . . . determine at what hour the registrant registered
  result = (registration_hour_day(row[:regdate]))
  reg_hour = result[0]

  # . . . determine what day the registrant registered
  reg_day = registration_day_name(result[1])

  # . . . add the registration hour to a list of registration hours
  tally_hours << reg_hour

  # . . . add the registration day to a list of registration days
  tally_days << reg_day
  
  # . . . generate a form letter to the registrant's legislator
  form_letter = erb_template.result(binding)

  # . . . save the form letter in a folder
  save_thank_you_letters(id,form_letter)
end
#determine the most active registration hours
target_hour = active_period tally_hours
peak_hours = popular_period target_hour

#convert times to standard times and print result to console
demilitarize_hour peak_hours

#determine the most active registration day of the week and print to console
target_day = active_period tally_days
peak_days = popular_period target_day
show_days peak_days


