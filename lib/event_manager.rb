require 'sinatra'
require 'csv'
require 'erb'
require 'sinatra/config_file'
require 'open-uri'
require 'JSON'
require 'pry'

config_file '../config.yml'

def clean_zipcode(zipcode)
  zipcode.to_s.rjust(5,"0")[0..4]
end

def legislators_by_zipcode(zipcode)
  response = open("https://congress.api.sunlightfoundation.com/legislators/locate?zip=#{zipcode}", "x-api-key" => settings.sunshine_api_key)
  parsed_response=JSON.parse(response.read)
  array_of_legislators = parsed_response["results"]
end

def save_thank_you_letters(id,form_letter)
  Dir.mkdir("output") unless Dir.exists?("output")

  filename = "output/thanks_#{id}.html"

  File.open(filename,'w') do |file|
    file.puts form_letter
  end
end

puts "EventManager initialized."

contents = CSV.open '../event_attendees.csv', headers: true, header_converters: :symbol

template_letter = File.read "views/form_letter.erb"
erb_template = ERB.new template_letter

contents.each do |row|
  id = row[0]
  name = row[:first_name]
  zipcode = clean_zipcode(row[:zipcode])
  legislators = legislators_by_zipcode(zipcode)
  binding.pry

  form_letter = erb_template.result(binding)

  save_thank_you_letters(id,form_letter)
end