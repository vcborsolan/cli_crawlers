require 'open-uri'
require 'selenium-webdriver'
require 'two_captcha'
require 'watir'

module Scrapers

    class Fazenda_pesquisar

        attr_accessor :url, :placa , :renavam , :hash_conteudo , :url_sucesso

        def initialize(placa , renavam)

            @placa = placa
            @url = "https://www.ipva.fazenda.sp.gov.br/IPVANET_Consulta/Consulta.aspx".freeze
            @url_sucesso = "https://www.ipva.fazenda.sp.gov.br/IPVANET_Consulta/Pages/Aviso.aspx".freeze
            @renavam = renavam
            @hash_conteudo = Hash.new("hash_conteudo")

        end
        
        def status_http(url)

            begin

                open(url).status.first

            rescue

            end

        end

        def tabeladpvat(driver)

            table = driver.elements(xpath: "//table[@id='conteudoPaginaPlaceHolder_tbDpvats']/tbody/tr/td")

            tabela = table.map {|r| r.text}

            tabela.delete("")

            tabela.delete("R$")

            tabela.delete("Guia de Arrecadação")

            tabela.delete("Exercício")

            tabela.delete("Valor")

            tabela1 = tabela.values_at(* tabela.each_index.select {|i| i.odd?})

            tabela2 = tabela.values_at(* tabela.each_index.select {|i| i.even?})

            tabela = [tabela2,tabela1]

            return tabela

        end

        def tabelaipvadebitoninscrito(driver)

            table = driver.elements(xpath: "//table[@id='conteudoPaginaPlaceHolder_tbIpvaPend']/tbody/tr/td")

            tabela = table.map {|r| r.text}

            tabela.delete(" ")

            tabela.delete("")

            tabela.delete("R$")

            tabela.delete("(Pague na rede bancária autorizada com o código RENAVAM)")

            tabela.delete("Exercício")

            tabela.delete("Valor")

            tabela1 = tabela.values_at(* tabela.each_index.select {|i| i.odd?})

            tabela2 = tabela.values_at(* tabela.each_index.select {|i| i.even?})

            tabela = [tabela2,tabela1]


            return tabela

        end

        def tabelataxas(driver)

            teste = driver.span id: 'conteudoPaginaPlaceHolder_txtLicenciamentoAno'

            if teste.text == ""

                table = driver.elements(xpath: "//table[@id='conteudoPaginaPlaceHolder_tbTaxasDetalhe']/tbody/tr/td")

                tabela = table.map {|r| r.text}

                tabela.delete(" ")

                tabela.delete("")

                tabela.delete("R$")

                tabela.delete_at(0)

                tabela1 = tabela.values_at(* tabela.each_index.select {|i| i.odd?})

                tabela2 = tabela.values_at(* tabela.each_index.select {|i| i.even?})

                tabela = [tabela2,tabela1]

                tabela.transpose

                return tabela

             else

                tabela = [[],[]]

                return tabela

            end

        end

        def tabelamultas(driver)

            table = driver.elements(xpath: "//table[@id='conteudoPaginaPlaceHolder_tbMultaResumo']/tbody/tr/td")

            tabela = table.map {|r| r.text}

            tabela.delete(" ")

            tabela.delete("")

            tabela.delete("R$")

            # tabela #=> ["Órgão", "Quantidade", "Valor", "MUNICIPAL", "4", "457,54", "D.E.R.", "1", "85,12"]

            pulo = (0..tabela.length).step(3)

            tabela_multa = []

            tabela.each_with_index do |dado , indice|

                pulo.each do |x|

                    if x == indice

                        tabela_multa.push(tabela[x..(x+2)])

                    end

                end

            end

            # tabela_multa #=> [["Órgão", "Quantidade", "Valor"], ["MUNICIPAL", "4", "457,54"], ["D.E.R.", "1", "85,12"]]

            return tabela_multa

        end

        def tabelaipvageral(driver)

            tabelas = driver.tables(class: 'loginTable')

            tabela = tabelas.select{ |x| / Base de Cálculo/.match(x.text)}

            tabela = tabela.first.text

            return tabela.tr('[]','').split("\n")

        end

        def comunicado(driver)

            comunicado = driver.div id: 'conteudoPaginaPlaceHolder_pnlComunicVenda'

            if comunicado.exists?

                return comunicado.text.to_s.gsub(/\n/ , ' ').strip

             else

                return "Nada Consta"

            end

        end

        def conteudo(driver)

            d = driver.span id: 'conteudoPaginaPlaceHolder_txtMarcaModelo'

            puts "#{d.text} - conteudo()"

            if  d.exists?

                dpvat = tabeladpvat(driver)
                ipvageral = tabelaipvageral(driver)
                ipvadebitoninscrito = tabelaipvadebitoninscrito(driver)
                taxas = tabelataxas(driver)
                multas = tabelamultas(driver)
                comunicado = comunicado(driver)

                @hash_conteudo = {

                    mmodelo: driver.element(:id ,'conteudoPaginaPlaceHolder_txtMarcaModelo').text ,
                    faixaipva: driver.element(:id ,'conteudoPaginaPlaceHolder_txtFaixaIPVA').text ,
                    anofabric: driver.element(:id ,'conteudoPaginaPlaceHolder_txtAnoFabric').text ,
                    municipio: driver.element(:id ,'conteudoPaginaPlaceHolder_txtMunicipio').text ,
                    combustivel: driver.element(:id ,'conteudoPaginaPlaceHolder_txtCombustivel').text ,
                    especie: driver.element(:id ,'conteudoPaginaPlaceHolder_txtEspecie').text ,
                    categoria: driver.element(:id ,'conteudoPaginaPlaceHolder_txtCategoria').text ,
                    passageiros: driver.element(:id ,'conteudoPaginaPlaceHolder_txtPassageiros').text ,
                    tipo: driver.element(:id ,'conteudoPaginaPlaceHolder_txtTipo').text ,
                    carroceria: driver.element(:id ,'conteudoPaginaPlaceHolder_txtCarroceria').text ,
                    ultlicenciamento: driver.element(:id ,'conteudoPaginaPlaceHolder_txtAnoUltLicen').text.to_s.gsub(/\n/ , ' ').strip ,
                    ipvadebitoninscrito: ipvadebitoninscrito ,
                    ipvadividaativa: driver.span(id: 'conteudoPaginaPlaceHolder_txtExisteDividaAtiva').text,
                    taxas: taxas ,
                    ipvageral: ipvageral ,
                    multas: multas ,
                    dpvat: dpvat ,
                    img: driver.span(id: 'conteudoPaginaPlaceHolder_txtValorTotalDebitos').text.to_s.gsub(/\n/ , ' ').strip ,
                    comunicado: comunicado
                }

            else

                @hash_conteudo[:erro] = "dados vazios"

            end

        end

        def resposta_captcha()

            client_options = {

                timeout: 360 ,
                polling: 10

            }

            client = TwoCaptcha.new(ENV["CAPTCHA_KEY"] , client_options)

            options_captcha = {googlekey: "6Led7bcUAAAAAGqEoogy4d-S1jNlkuxheM7z2QWt" ,
            pageurl: "https://www.ipva.fazenda.sp.gov.br/IPVANET_Consulta/Consulta.aspx"}

            @resposta_captcha = client.decode_recaptcha_v2(options_captcha)

        end

        def tratamento(string)

            string.to_s.gsub(/\n/ , ' ').strip

        end

        def valida_captcha(driver)

            puts "3 - valida captcha"

            a = driver.span id: 'conteudoPaginaPlaceHolder_CustomValidator4'

            if a.exists?

                if a.text == "Caracteres digitados não correspondem aos caracteres da imagem"

                    puts "#{a.text} - valida_captcha "

                    @hash_conteudo[:erro] = "erro captcha"

                end

            else

                conteudo(driver)

            end

        end

        def valida_digita_captcha(driver)

            puts "2 - valida digita captcha"

            b = driver.span id: 'conteudoPaginaPlaceHolder_RequiredFieldValidator14'

            if b.exists?

                if b.text == "Campo 'caracteres da imagem' de preenchimento obrigatório"

                    puts "#{b.text} - valida_digita_captcha"

                    @hash_conteudo[:erro] = "captcha vazio"

                end

                @hash_conteudo[:erro] = "captcha vazio"

            else

                valida_captcha(driver)

            end

        end

        def valida_existe(driver)

            puts "1 - valida existe"

            c = driver.execute_script("var c = document.getElementById('conteudoPaginaPlaceHolder_lblErro') ; return c ;")

            if !c.nil?

                puts "#{c.text} - valida_existe"

                if c.text == "RENAVAM/PLACA NÃO ENCONTRADOS"

                    @hash_conteudo[:erro] = "Combinação Inexistente"

                end

                @hash_conteudo[:erro] = "Combinação Inexistente"

             else

                valida_digita_captcha(driver)

            end

        end

        def pesquisar()

            status = status_http(url)

            if status == "200"

                driver = Watir::Browser.new:firefox , headless: true

                driver.goto url

                # Watir::Wait.until { driver.element(:id , "imgCaptcha").exists? }

                # sleep(5)

                # encoded = driver.execute_script("var canvas, ctx, dataURL, base64;canvas = document.createElement('canvas');ctx = canvas.getContext('2d');canvas.width = (document.getElementById('imgCaptcha').width)+50;canvas.height = (document.getElementById('imgCaptcha').height)+50;ctx.drawImage(document.getElementById('imgCaptcha'), 0, 0);dataURL = canvas.toDataURL('image/png');base64 = dataURL;return base64 ;")

                sleep(5)

                captcha = resposta_captcha()

                input_placa = driver.element(:id, "conteudoPaginaPlaceHolder_txtPlaca")

                input_placa.send_keys(@placa)

                input_renavam = driver.element(:id , "conteudoPaginaPlaceHolder_txtRenavam")

                input_renavam.send_keys(@renavam)

                input_captcha = driver.element(:id , "conteudoPaginaPlaceHolder_txtCaptcha")
    
                # input_captcha.send_keys(captcha.text)

                driver.execute_script("document.getElementById('g-recaptcha-response').style.display = 'block';") #js para mostrar o textbox onde insere resposta

                sleep(2)

                driver.element(:id , "g-recaptcha-response").send_keys @resposta_captcha.text #insere resposta captcha

                btn_submit =  driver.element(:id , "conteudoPaginaPlaceHolder_btn_Consultar")
    
                btn_submit.click

                valida_existe(driver)

                driver.quit

                return @hash_conteudo

             else

                @hash_conteudo[:erro] = "status <> 200"

            end

        end

    end

end
