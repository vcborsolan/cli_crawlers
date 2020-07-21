require "thor"
require 'dotenv/load'

class Crawl < Thor
    desc "key string", "Update the two_captcha key in enviroment , if there it is no .env or no CAPTCHA_KEY , create one"
    def update_key(key)

        ENV['CAPTCHA_KEY'].nil?  ? create_private_key(key) : update_private_key(key)

    end


    private

    def update_private_key(key)
        file = File.read('.env')
        new_env = file.gsub("CAPTCHA_KEY=#{ENV['CAPTCHA_KEY']}", "CAPTCHA_KEY=#{key}")
        File.open('.env', 'w') { |line| line.puts new_env }
    end

    def create_private_key(key)
        File.new('.env', 'w') do |file|
            file.write("CAPTCHA_KEY=#{key}")
        end
    end
end