require 'open-uri'
require 'watir'
require 'two_captcha'

module Scrapers

    class Denatran_pesquisar

        URL_OK = "https://portalservicos.denatran.serpro.gov.br/#/login".freeze
        URL_HOME = "https://portalservicos.denatran.serpro.gov.br/#/home".freeze
        URL_VEICULO = "https://portalservicos.denatran.serpro.gov.br/#/veiculo".freeze

        attr_accessor :hash_conteudo , :array_veiculos , :user , :driver , :captcha

        def initialize(array_veiculos , user_denatran)

            @array_veiculos = array_veiculos
            @user = user_denatran
            @captcha = resposta_captcha
            @driver = Watir::Browser.new:firefox , headless: true
            @hash_conteudo = Hash.new("hash_conteudo")

        end

        def resposta_captcha

            client_options = {

                timeout: 360 ,
                polling: 10

            }

            client = TwoCaptcha.new(ENV["CAPTCHA_KEY"] , client_options)

            options_captcha = {googlekey: "6Le2WC8UAAAAAIh_gGD1DOozEVF3Q6PKYVir_V_t" ,
            pageurl: "https://portalservicos.denatran.serpro.gov.br/#/login"}

            client.decode_recaptcha_v2(options_captcha)

        end

        def status_http(url)

            begin

                open(url).status.first

            rescue

            end

        end

        def busca_denatran

            status = status_http(URL_OK)

            if status == "200"

                @driver.goto URL_OK

                while @driver.url != URL_OK

                    sleep(2)

                end

                @driver.element(:id , "cpf").send_keys @user[:user]

                @driver.element(:id , "senha").send_keys @user[:password]

                @driver.execute_script("document.getElementById('g-recaptcha-response').style.display = 'block';")

                @driver.element(:id , "g-recaptcha-response").send_keys @captcha.text

                @driver.element(:xpath , "//a[contains(text(),'Entrar')]").click

                sleep(5)

                @driver.element(:xpath , "//div[@class='alert alert-danger ng-binding ng-scope']").exists? ? get_erro_login : get_pesquisa

             else

                @driver.quit

            end

        end

        def get_erro_login

            @hash_conteudo = {erro: @driver.element(:xpath , "//div[@class='alert alert-danger ng-binding ng-scope']").text }

            @driver.quit

            return @hash_conteudo

        end

        def get_pesquisa

            while @driver.url != URL_HOME

                sleep(2)

            end

            tmp_array = []

            @array_veiculos.each do |dado|

                @driver.goto URL_VEICULO

                tmp_array << pesquisar_veiculo(dado)

                @driver.goto "https://portalservicos.denatran.serpro.gov.br/#/home"

            end

            @hash_conteudo = {
                resultado: tmp_array
            }

            @driver.quit

            return @hash_conteudo

        end

        def pesquisar_veiculo(dado)

            while @driver.url != URL_VEICULO

                sleep(2)

            end

            @driver.element(:id , "renavam").send_keys dado[:renavam]
            @driver.element(:id , "placa").send_keys dado[:placa]
            @driver.element(:id , "ni").send_keys dado[:documento]
            @driver.element(:xpath , "//a[contains(text(),'Prosseguir')]").click

            sleep(15)

            case @driver.div(:id , "consulta_detalhamento" ).text

              when /Limite diário de consultas atingido/
                return {erro: "limite de pesquisa" , veiculo: dado}

              when /Veículo não encontrado/
                return {erro: "veiculo não encontrado", veiculo: dado}

              when /ATENÇÃO/
                return {veiculo: get_dados(dado)}

              else
                return {erro: "timeout" , veiculo: dado}

            end

        end

        def get_dados(dado)

            array_info = [dado]

            array_info << @driver.element(:id , "infoVeiculo").text

            @driver.element(:xpath , "//uib-tab-heading[contains(text(),'Indicadores de Situação do Veículo')]").click

            sleep(2)

            array_info << @driver.element(:xpath , "//div[@class='tab-pane ng-scope active']//table[@class='table table-striped table-hover']").text

            sleep(2)

            array_info = tratar_resultado(array_info)

            return array_info

        end

        def tratar_resultado(array)

            # [{placa: ENC8074 , renavam: 00193347334 , documento: 39795736809},"Placa Atual: ENC8074\nCódigo RENAVAM: 00193347334\nCPF/CNPJ do Proprietário: 397.957.368-09\nNome do Proprietário: PATRICIA REGINA LUHMANN BOLSONI\nTipo: AUTOMOVEL\nEspécie: PASSAGEIRO\nCarroceria: NãO APLICAVEL\nCategoria: PARTICULAR\nCombustível: ALCOOL/GASOLINA\nMarca/Modelo: VW/FOX 1.0 GII\nAno Fabricação: 2009\nAno Modelo: 2010\nCor: PRATA\nLotação: 5\nCapacidade de Carga: 0\nPotência: 76\nCilindradas: 999", "Restrição-1: ALIENACAO FIDUCIARIA\nRestrição-2: Não há\nRestrição-3: Não há\nRestrição-4: Não há\nExiste ocorrência de furto/roubo ativa? Não\nExiste comunicação de venda ativa? Não\nExiste restrição judicial RENAJUD? Não\nExiste multa RENAINF? Sim\nExiste recall? Não"]

            tratado = {

                veiculo: array[0] ,
                placa: array[0][:placa] ,
                renavam: array[0][:renavam] ,
                documento: array[0][:documento] ,
                nomeProprietario: tratarbarran(array[1].scan(/Nome do Proprietário: [A-Z áàãâÀÁÃÂçÇimo \W 0-9]{10,50}/).first.gsub("Nome do Proprietário: " , "")) ,
                tipo: tratarbarran(array[1].scan(/Tipo: [A-Z áàãâÀÁÃÂçÇimo \W 0-9]{1,20}/).first.gsub("Tipo: ","")) ,
                especie: tratarbarran(array[1].scan(/Espécie: [A-Z áàãâÀÁÃÂçÇimo \W 0-9]{1,30}/).first.gsub("Espécie: ", "")) ,
                carroceria: array[1].scan(/Carroceria: [A-Z áàãâÀÁÃÂçÇ]{1,30}/).first.gsub("Carroceria: ", "") ,
                categoria: array[1].scan(/Categoria: [A-Z áàãâÀÁÃÂçÇ]{1,30}/).first.gsub("Categoria: ", "") ,
                combustivel: tratarbarran(array[1].scan(/Combustível: [A-Z áàãâÀÁÃÂçÇ\W]{1,30}/).first.gsub("Combustível: ", "")) ,
                mModelo: tratarbarran(array[1].scan(/Marca.Modelo: [A-Z áàãâÀÁÃÂçÇ \W 0-9]{1,30}/).first.gsub("Marca.Modelo: ", "")) ,
                anoFabric: array[1].scan(/Ano Fabricação: [0-9]{1,4}/).first.gsub("Ano Fabricação: ", "") ,
                anoModelo: array[1].scan(/Ano Modelo: [0-9]{1,4}/).first.gsub("Ano Modelo: ","") ,
                cor: array[1].scan(/Cor: [A-Z áàãâÀÁÃÂçÇ]{1,30}/).first.gsub("Cor: ", "") ,
                lotacao: array[1].scan(/Lotação: [0-9]{1,3}/).first.gsub("Lotação: ", "") ,
                capCarga: array[1].scan(/Capacidade de Carga: [0-9]{1,10}/).first.gsub("Capacidade de Carga: ", "") ,
                potencia: array[1].scan(/Potência: [0-9]{1,4}/).first.gsub("Potência: ", "") ,
                cilindradas: array[1].scan(/Cilindradas: [0-9]{1,4}/).first.gsub("Cilindradas: ", "") ,
                rest1: tratarbarran(array[2].scan(/Restrição-1: [A-Z áàãâÀÁÃÂçÇimo \W 0-9]{1,30}/).first.gsub("Restrição-1: ", "")) ,
                rest2: tratarbarran(array[2].scan(/Restrição-2: [A-Z áàãâÀÁÃÂçÇimo \W 0-9]{1,30}/).first.gsub("Restrição-2: ", "")) ,
                rest3: tratarbarran(array[2].scan(/Restrição-3: [A-Z áàãâÀÁÃÂçÇimo \W 0-9]{1,30}/).first.gsub("Restrição-3: ", "")) ,
                rest4: tratarbarran(array[2].scan(/Restrição-4: [A-Z áàãâÀÁÃÂçÇimo \W 0-9]{1,30}/).first.gsub("Restrição-4: ", "")) ,
                furtoRoubo: tratarbarran(array[2].scan(/Existe ocorrência de furto.roubo ativa. [A-Z áàãâÀÁÃÂçÇimo \W 0-9]{1,30}/).first.gsub("Existe ocorrência de furto/roubo ativa? ", "")) ,
                comunicadoVenda: tratarbarran(array[2].scan(/Existe comunicação de venda ativa. [A-Z áàãâÀÁÃÂçÇimo \W 0-9]{1,30}/).first.gsub("Existe comunicação de venda ativa? ", "")) ,
                renajud: tratarbarran(array[2].scan(/Existe restrição judicial RENAJUD. [A-Z áàãâÀÁÃÂçÇimo \W 0-9]{1,30}/).first.gsub("Existe restrição judicial RENAJUD? ", "")) ,
                renaif: tratarbarran(array[2].scan(/Existe multa RENAINF. [A-Z áàãâÀÁÃÂçÇimo \W 0-9]{1,30}/).first.gsub("Existe multa RENAINF? ", "")) ,
                recall: array[2].scan(/Existe recall. [A-Z áàãâÀÁÃÂçÇimo \W 0-9]{1,30}/).first.gsub("Existe recall? ", "") ,
            }

        end

        def tratarbarran(dado)

            length = dado.length

            dado = dado[0..length-3]

        end

    end

end