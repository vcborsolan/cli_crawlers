require 'selenium-webdriver'
require 'two_captcha'
require 'watir'
require 'byebug'

module Scrapers

    class Renavam_pesquisar

        BASE_URL="https://www.dividaativa.pge.sp.gov.br/da-ic-web/".freeze #url padrão inicial

        URL_OK="https://www.dividaativa.pge.sp.gov.br/da-ic-web/consultaDebitosNormais.do?tipoConsulta=termoAceite".freeze #url sem apos navegacao

        URL_ERRO = "https://www.dividaativa.pge.sp.gov.br/da-ic-web/erroSessao.do".freeze

        attr_accessor :driver , :renavam , :captcha , :hash_conteudo
        def initialize(renavam)

            @renavam = renavam

            @captcha = resposta_captcha

            @hash_conteudo = Hash.new("hash_conteudo")

            @driver = Watir::Browser.new:firefox , headless: true

        end

        def resposta_captcha

            client_options = {

                timeout: 360 ,
                polling: 10

            }

            client = TwoCaptcha.new(ENV["CAPTCHA_KEY"] , client_options)

            options_captcha = {googlekey: "6LeeDDoUAAAAAL7awoPJgSMuiF6AuJW5rf0zqEfy" ,
            pageurl: "https://www.dividaativa.pge.sp.gov.br/da-ic-web/erroSessao.do"}

            client.decode_recaptcha_v2(options_captcha)

        end

        def status_http(url)

            begin

                open(url).status.first

            rescue

            end

        end

        def valida_erro(driver)

            erro = driver.td class: 'rotuloErro'

            if erro.exists?

                if erro.text == "Não foram encontrados débitos para os dados informados."

                    @hash_conteudo[:erro] = "Não constam debitos"

                 elsif erro.text == "Valor do documento inválido."

                    @hash_conteudo[:erro] = "Valor do documento inválido."

                 elsif erro.text == "Sessão Expirada. Por favor refaça sua consulta."

                    @hash_conteudo[:erro] = "Sessão Expirada. Por favor refaça sua consulta."

                end

             else

                @hash_conteudo[:erro] = nil

            end

        end

        def get_conteudo(driver)

            ipva = driver.link text: 'IPVA'

            sleep(5)

            if ipva.exists?

                driver.element(:link_text , "IPVA").click

                sleep(5)

                a = driver.elements(:tag_name , "a")

                a = a.map{|a| a.text.gsub("." , "")}

                a = a.select { |a| a.size == 10}

                # puts " ========================== "

                # a.each_with_index do |dado , indice|
                #     puts "#{dado} : #{indice}"
                # end

                # puts " ========================== "

                @hash_conteudo[:cdas] = a

             else

                cdas = driver.elements(:tag_name , "td")

                hash_conteudo = cdas.map {|cda| cda.text[(/^\d{10}$/)]}

                hash_conteudo.delete(nil)

                @hash_conteudo[:cdas] = hash_conteudo

            end

        end

        def status_http(url)

            begin

                open(url).status.first

            rescue

            end

        end

        def busca_renavam

            status = status_http(BASE_URL)

            if status == "200"

                driver.goto BASE_URL #setando o driver p a url inicial

                cookies = driver.cookies[:JSESSIONID]

                puts cookies

                driver.cookies.add(cookies[:name] , cookies[:value])

                driver.goto URL_OK

                sleep(2)

                while driver.url != URL_OK

                    sleep(2)

                    driver.goto URL_OK

                end

                selecionado = driver.element(:xpath ,"//option[@value='7']").click #seleciona a opção CDA

                driver.element(:id , "campo").send_keys @renavam #colocando a cda no textbox

                driver.execute_script("document.getElementById('g-recaptcha-response').style.display = 'block';") #js para mostrar o textbox onde insere resposta

                driver.element(:id , 'g-recaptcha-response').send_keys captcha.text #insere resposta captcha

                driver.element(:class , 'pressionado').click #clicka para enviar form

                sleep(5)

                valida_erro(driver)

                sleep(5)

                if @hash_conteudo[:erro].nil?

                    sleep(2)

                    get_conteudo(driver)

                end

                driver.quit

                return hash_conteudo

             else

                @hash_conteudo[:erro] = "status <> 200"

                return @hash_conteudo

            end

        end
    
    end

end
