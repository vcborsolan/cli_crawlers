require 'two_captcha'
require 'watir'

module Scrapers

    class Cda_gare

        BASE_URL="https://www.dividaativa.pge.sp.gov.br/da-ic-web/".freeze #url padrão inicial

        URL_OK="https://www.dividaativa.pge.sp.gov.br/da-ic-web/consultaDebitosNormais.do?tipoConsulta=termoAceite".freeze #url sem apos navegacao

        URL_ERRO = "https://www.dividaativa.pge.sp.gov.br/da-ic-web/erroSessao.do".freeze

        attr_accessor :driver , :wait , :options , :hash_conteudo , :captcha

        def initialize(cda , cod_arquivo)

            @cda = "#{cda[0]}.#{cda[1..3]}.#{cda[4..6]}.#{cda[7..9]}"

            @hash_conteudo = Hash.new("hash_conteudo")

            system("sudo chmod -R 777 #{Rails.root}")
            directory_arquivo = "#{Rails.root}/tmp/GARE/#{cod_arquivo}"
            download_directory = "#{directory_arquivo}/#{cda}"
            File.directory?("#{Rails.root}/tmp/GARE") ? puts("existe pasta GARE") : system("sudo mkdir -m 777 #{Rails.root}/tmp/GARE")
            File.directory?(directory_arquivo) ? puts("existe pasta com cod_arquivo") : system("sudo mkdir -m 777 #{directory_arquivo}")
            File.directory?(download_directory) ? puts("existe pasta com cda") : system("sudo mkdir -m 777 #{download_directory}")
            profile = Selenium::WebDriver::Firefox::Profile.new
            profile['browser.download.folderList'] = 2 # custom location
            profile["browser.download.useDownloadDir"] = true
            profile['browser.download.dir'] = download_directory
            profile["pdfjs.disabled"] = true
            profile['browser.helperApps.neverAsk.saveToDisk'] = 'application/pdf'

            @driver = Watir::Browser.new:firefox , profile: profile , headless: true

            # @driver = Watir::Browser.new :firefox , profile: profile

            @captcha = nil

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

                sleep(5)

                valida_tela2(driver)

            end

        end

        #  CDA TESTE = 1226213373

        def valida_tela2(driver)

            sleep(5)

            # byebug

            tela2 = driver.element(:xpath , "//a[contains(text(),'IPVA')]")

            if tela2.exists?

                tela2.click

                valida_tela3(driver)

             else

                @hash_conteudo[:erro] = "Erro durante tela 2"

            end

        end

        def valida_tela3(driver)

            sleep(5)

            tela3 = driver.link text: "liquidar"

            if tela3.exists?

                tela3.click

                sleep(5)

                valida_tela4(driver)

             else

                @hash_conteudo[:erro] = "Erro durante tela 3"

            end

        end

        def valida_tela4(driver)

            # byebug
            
            tela4 = driver.element(:xpath , "//input[@value='Gerar GARE']")

            if tela4.exists?

                puts("Tela 4 existe")

                tela4.click

                puts("Clicou no botão gerar gare")

                sleep(5)
 
                driver.alert.ok

                puts("Clickou no alerta")

                sleep(5)

                btn_download = driver.element(:xpath , "//input[@value='Download Gare']")

                puts("Achou o botao de download gare")

                sleep(5)

                btn_download.click

                puts("Clickou no botão de download")

                @hash_conteudo = {

                    download: true
        
                }

             else

                @hash_conteudo[:erro] = "Não encontrou botão gerar gare / download gare"

            end

        end

        def status_http(url)

            begin

                open(url).status.first

            rescue

            end

        end

        def busca_cda
            puts "-----------------------------------"
            puts "-----------------------------------"
            puts ""
            puts ""
            puts "começou a pesquisa cda = #{@cda}"
            puts ""
            puts ""
            puts "-----------------------------------"
            puts "-----------------------------------"

            status = status_http(BASE_URL)

            if status == "200"

                @captcha = resposta_captcha

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

                selecionado = driver.element(:xpath , "//option[@value='4']") #seleciona a opção CDA

                selecionado.click

                driver.element(:id , "campo").send_keys @cda #colocando a cda no textbox

                driver.execute_script("document.getElementById('g-recaptcha-response').style.display = 'block';") #js para mostrar o textbox onde insere resposta

                sleep(2)

                driver.element(:id , "g-recaptcha-response").send_keys @captcha.text #insere resposta captcha

                sleep(2)

                driver.element(:class , 'pressionado').click #clicka para enviar form

                sleep(5)

                valida_erro(driver)

                @hash_conteudo[:download] = false if @hash_conteudo[:download].nil?

                driver.quit

                return @hash_conteudo

             else

                @hash_conteudo[:erro] = "status <> 200"

                return @hash_conteudo

            end

        end

    end

end