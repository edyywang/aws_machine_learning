# load 'aws_machine_learning.rb'

require 'dotenv'
require 'google/apis/drive_v2'
require 'uri'
require 'net/http'
require 'openssl'
require 'json'
require 'base64'

class AwsMachineLearning

  Dotenv.load
  MACHINE_LEARNING_ACCESS_KEY = ENV['MACHINE_LEARNING_ACCESS_KEY']
  MACHINE_LEARNING_SECRET_KEY = ENV['MACHINE_LEARNING_SECRET_KEY']

  def initialize
    @type = type
  end

  def upload_file(file_name = 'sample.jpg')
    file_path = "#{FILE_FOLDER}#{file_name}"
    process_image_file(file_path, REQUEST_FILE_NAME)

    api_url = URI("https://vision.googleapis.com/v1/images:annotate?key=#{BROWSER_API_KEY}")
    http = Net::HTTP.new(api_url.host, api_url.port)
    http.use_ssl = true
    http.verify_mode = OpenSSL::SSL::VERIFY_NONE

    request = Net::HTTP::Post.new(api_url)
    request["content-type"] = 'application/json'
    request["cache-control"] = 'no-cache'
    request.body = File.read(REQUEST_FILE_NAME)
    response = http.request(request)
    if response.code.start_with?('20')
      process_result(response.read_body)
    else
      fail "FAILED: #{response.read_body}"
    end
  end

  def process_image_file(file_path, request_file_name)
    image_file = Base64.encode64( File.open(file_path, 'rb') {|file| file.read } ).strip
    request_json = JSON.generate("requests" => [{
                                              "image" => { "content" => "#{image_file}" },
                                              "features" => [{ "type" => "#{@type}", "maxResults" => "#{max_results}" }]
                                            }])
    File.open(request_file_name,"w") do |f|
      f.write(request_json)
    end
  end

  def max_results
    case @type
    when 'LABEL_DETECTION'
      5
    when 'SAFE_SEARCH_DETECTION'
      1
    else
      3
    end
  end

  def process_result(response_read_body)
    case @type
    when 'LABEL_DETECTION'
      process_label_detection(response_read_body)
    when 'SAFE_SEARCH_DETECTION'
      process_safe_search_detection(response_read_body)
    else
      puts "#{response_read_body}"
    end
  end

  def process_label_detection(response_read_body)
    result = JSON.parse(response_read_body).to_hash
    description = result['responses'].first['labelAnnotations'].first['description']
    score = result['responses'].first['labelAnnotations'].first['score']

    puts "description: #{description}"
    puts "score: #{score}"

    puts "========RESULT========"
    puts "#{response_read_body}"
  end

  def process_safe_search_detection(response_read_body)
    result = JSON.parse(response_read_body).to_hash
    adult = result['responses'].first['safeSearchAnnotation']['adult']
    spoof = result['responses'].first['safeSearchAnnotation']['spoof']
    medical = result['responses'].first['safeSearchAnnotation']['medical']
    violence = result['responses'].first['safeSearchAnnotation']['violence']
    content_safe = adult.include?('UNLIKELY') and spoof.include?('UNLIKELY') and medical.include?('UNLIKELY') and violence.include?('UNLIKELY')

    if content_safe
      puts "content save"
    else
      puts "adult: #{adult}" unless adult.include? 'UNLIKELY'
      puts "spoof: #{spoof}" unless spoof.include? 'UNLIKELY'
      puts "medical: #{medical}" unless medical.include? 'UNLIKELY'
      puts "violence: #{violence}" unless violence.include? 'UNLIKELY'
    end

    puts "========RESULT========"
    puts "#{response_read_body}"
  end
end
