require 'two_captcha'
require 'watir'

module Scrapers

    class Cda_pesquisar

        BASE_URL="https://www.dividaativa.pge.sp.gov.br/da-ic-web/".freeze #url padrão inicial

        URL_OK="https://www.dividaativa.pge.sp.gov.br/da-ic-web/consultaDebitosNormais.do?tipoConsulta=termoAceite".freeze #url sem apos navegacao

        URL_ERRO = "https://www.dividaativa.pge.sp.gov.br/da-ic-web/erroSessao.do".freeze

        attr_accessor :driver , :wait , :options , :hash_conteudo , :captcha

        def initialize(cda)

            @cda = "#{cda[0]}.#{cda[1..3]}.#{cda[4..6]}.#{cda[7..9]}"

            @hash_conteudo = Hash.new("hash_conteudo")

            @driver = Watir::Browser.new:firefox , headless: true

            # @driver = Watir::Browser.new:firefox

            @captcha = nil

        end

        def resposta_captcha

            client_options = {

                timeout: 360 ,
                polling: 10

            }

            client = TwoCaptcha.new('39f154fa6e5fc21fc620ddb4c9c2ee79' , client_options)

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

            tela3 = driver.link text: "#{@cda}"

            if tela3.exists?

                tela3.click

                sleep(5)

                valida_tela4(driver)

             else

                @hash_conteudo[:erro] = "Erro durante tela 3"

            end

        end

        def valida_tela4(driver)

            tela4 = driver.td(index: 15)

            if tela4.exists?

                if tela4.text == "#{@cda}"

                    conteudo(driver)

                 else

                    puts "#{tela4.text} - valida_tela4"

                    @hash_conteudo[:erro] = "Erro durante tela 4"

                    return

                end

             else

                @hash_conteudo[:erro] = "Erro durante tela 4"

                return

            end

        end

        def jurosMMM(conteudo , driver)

            juros = conteudo.map{|x| x.scan(/^Juros de Mora da Multa de Mora R. [0-9.]{1,10},[0-9]{2}/)}.flatten.first

            juros = juros.nil? ? "0" : juros.gsub("Juros de Mora da Multa de Mora R$ ","")

        end

        def conteudo(driver)

            conteudo = driver.element(:xpath , "//form[@id='acoesDebitos']").text.split(/\R+/)
            linhaDivida = conteudo.map{|x| x.scan(/^[A-Z]{2,3}[0-9]{3,4} [0-9]{9,12} .{20,150}/)}.flatten
            # byebug
            linhaDividaSize = linhaDivida.first.split(" ").size


            @hash_conteudo = {

                devedor: conteudo[3].gsub("Devedor: " ,""),
                cnpj: conteudo[4].gsub("CNPJ/CPF ",""),
                dtInclu: conteudo[6].gsub("Data de Inscrição na dívida Ativa: " ,"") ,
                nroProUni: conteudo[7].gsub("Número do Processo (Unificado): ","") ,
                nroProOut: conteudo[8].gsub("Número do Processo (Outros): " ,"") ,
                situacao: conteudo[9].gsub("Situação: ","") ,
                saldo: conteudo[10].gsub("Saldo: R$ ","") ,
                principal: conteudo[12].gsub("Principal R$ " , ""),
                jurosMP: conteudo[13].gsub("Juros de Mora do Principal R$ " ,""),
                multaMP: conteudo.map{|x| x.scan(/^Multa de Mora do Principal R. [0-9.]{1,10},[0-9]{2}/)}.flatten.first.gsub("Multa de Mora do Principal R$ ",""),
                honorario: conteudo.map{|x| x.scan(/^Honorários Advocatícios R. [0-9.]{1,10},[0-9]{2}/)}.flatten.first , 
                jurosMMM: jurosMMM(conteudo , driver) ,
                placa: linhaDivida.first.split(" ")[0] ,
                renavam: linhaDivida.first.split(" ")[1] ,
                chassi: linhaDivida.first.split(" ")[2] ,
                mmdole: linhaDivida.first.split(" ")[3..(linhaDividaSize-7 + 3)].join(" ") ,
                ano: linhaDivida.first.split(" ")[linhaDividaSize-7 + 4] ,
                exercicio: linhaDivida.first.split(" ")[linhaDividaSize-7 + 5] ,
                parcelaNP: linhaDivida.first.split(" ")[linhaDividaSize-7 + 6] ,
                obs: linhaDivida.to_s

            }

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

                puts @hash_conteudo

                driver.quit

                return @hash_conteudo

             else

                @hash_conteudo[:erro] = "status <> 200"

                return @hash_conteudo

            end

        end

    end

end