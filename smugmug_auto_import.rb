require 'net/https'
require 'uri'
require 'rubygems'
require 'json'
require 'open-uri'
require 'mail'
require 'yaml'

@options = YAML.load_file('config.yml')

@tag = @options['tag'] || 'smugmug'
@user_id = @options['instagram_id'] || 216881
@min_filename = "min_id_#{@user_id}.txt"
@smugmug_subject = '#' + @tag

def read_min_id
  id = ''
  if File.exists?(@min_filename)
    file = File.open(@min_filename, "rb")
    id = file.read
  end
  return id
end

def write_min_id(id)
  File.open(@min_filename, 'w+') { |file| file.write(id) }
end

def download_image(url)
  filename = url.split('/').last
  open(filename, 'wb') do |file|
    file << open(url).read
  end
  return filename
end

def email_smugmug(file, caption)
  from_email = @options['from_email']
  to_email = @options['smugmug_email']
  mail = Mail.new do
    from from_email
    to to_email
    subject @smugmug_subject
    body caption
    add_file file
  end

  mail.delivery_method :sendmail
  mail.deliver
end

@min_id = read_min_id

url = "https://api.instagram.com/v1/users/#{@user_id}/media/recent/" +
  '?access_token=' + @options['access_token'] +
  "&count=10"

if !@min_id.empty?
  url += "&min_id=#{@min_id}"
end

uri = URI.parse(url)

http = Net::HTTP.new(uri.host, uri.port)
http.use_ssl = true
http.verify_mode = OpenSSL::SSL::VERIFY_NONE

request = Net::HTTP::Get.new(uri.request_uri)

response = http.request(request)
body = response.body
failed = false
begin
  content = JSON.parse(body)
rescue Exception => e
  return
end
@min_id = @min_id.to_i

content['data'].each do |data|
  tags = data['tags']
  id = data['id'].split('_').first.to_i
  if id > @min_id
    @min_id = id
    if tags.include?(@tag)
      img_url = data['images']['standard_resolution']['url']
      file = download_image(img_url)
      email_smugmug(file, data['caption']['text'])
    end
    write_min_id(@min_id)
  end
end

