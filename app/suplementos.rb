require 'open-uri'
require 'mechanize'
require 'watir'


module Scrapers

    class Suplementos_pesquisar

        attr_accessor :url, :placa , :ano , :status , :url_minimo , :retorno_pdf , :hash_conteudo

        def initialize(placa , ano)

            @placa = placa
            @url = "https://www.imprensaoficial.com.br/DO/BuscaDO2001Resultado_11_3.aspx?filtropalavraschave=#{placa}&f=xhitlist&xhitlist_vpc=first&xhitlist_x=Advanced&xhitlist_q=(EFF8058)&xhitlist_mh=9999&filtrotipopalavraschavesalvar=UP&filtrotodoscadernos=True&xhitlist_hc=%5bXML%5d%5bKwic%2c3%5d&xhitlist_vps=15&xhitlist_xsl=xhitlist.xsl&xhitlist_s=&xhitlist_sel=title%3bField%3adc%3atamanho%3bField%3adc%3adatapubl%3bField%3adc%3acaderno%3bitem-bookmark%3bhit-context".freeze
            @ano = ano
            @url_minimo = "https://www.imprensaoficial.com.br".freeze
            @status = status_http(@url)
            @hash_conteudo = Hash.new("hash_conteudo")

        end

        def status_http(url)

            open(url).status.first

        end

        def pesquisar()

            agent = Mechanize.new

            page = agent.get(@url)

            if page.uri.to_s == "https://www.imprensaoficial.com.br/DO/BuscaDO2001ResultadoNegativo_11_3a.aspx?filtropalavraschave=#{@placa}"

                @hash_conteudo[:erro] = "Não constam dados acerca da placa"

                return @hash_conteudo

             else

                links = page.search("a[@class='bg-light text-dark']")

                # ^^ procura todas os links cujo tem textos abreviados para pesquisa parcial

                if procurar_td(links.text)

                    # ^^ Verifica se nos textos contem uma sequencia de placa e ano , caso contrario não prossegue com pesquisa e retorna o erro especifico

                    links.each do |link|

                        tratar_td(link)

                        # Entra em cada link e procura se o texto esta completo da maneira necessaria , caso contrario faz a chamada para procurar dentro do pdf do respectivo link vide function

                    end

                end

                return @hash_conteudo

            end

        end

        def tratar_td(string)

            txt = string.text.scan(/[A-Z ÍÓÚÉÃÕÒÙÀÈ\D]{4,40} [0-9]{1,14} #{placa} [0-9]{9} #{@ano} [0-9]{1,6},[0-9]{2} [0-9]{1,6},[0-9]{2} [0-9]{1,6},[0-9]{2} [A-Z][a-zA-Z]{0,8}\W?[A-Z]{0,1}[a-z]{0,10}/)

            if txt.nil?

                txt = string.text.scan(/[A-Z ÍÓÚÉÃÕÒÙÀÈ\D]{4,40} [0-9]{1,14} #{placa} [0-9]{9} #{@ano} [0-9]{1,6},[0-9]{2} [0-9]{1,6},[0-9]{2} [0-9]{1,6},[0-9]{2} [A-Z][a-zA-Z]{0,8} [A-Z]{0,1}[a-z]{0,10}/)

            end

            if txt.length < 1

                # ^^ Se não encontrou nos dois padrões acima , verifica ao menos se o link passado tem a placa e ano para poder pesquisar no pdf

                pesquisar_pdf("#{@url_minimo}#{string.search("@href").text}") if string.text.match?(/#{placa} [0-9]{9} #{@ano}/) 

             else 

                # ^^ neste caso encontrou nos dois padrões  , é dado continuidade para o retorno dos dados

                nome = txt.to_s.scan(/[A-Z ÍÓÚÉÃÕÒÙÀÈÂ\Da-z]{4,100}/)[0].match(/[A-Z\W ]{4,100}$/)[0]
                
                # ^^ primeiro scan pega o nome do texto , o segundo pega o padrão de nome só que de tras para frente , retirando assim a sujeira de nome de cidade
                cpf = txt.to_s.scan(/[0-9]{14}/)[0]
                ncontrole = txt.to_s.scan(/[0-9]{9}/)[1]
                valores = txt.to_s.scan(/[0-9]{1,6},[0-9]{2}/)
                pfiscal = txt.to_s.scan(/[A-Z][a-z]{1,10} [A-Z]{0,1}[a-z]{0,10}/)

                pfiscal = txt[0].scan(/[A-Z ]{4,20}$/)[0] if pfiscal[0].nil?
                pfiscal = txt[0].scan(/.{20}$/) if pfiscal.nil?

                # Abaixo em posto fiscal há uma validação , pois se foi retornado um array , o primeiro só pode ser o nome do individuo , importante enviar como parametro uma string para que possa passar pelo filtro dentro da classe
                conteudo(nome , cpf , ncontrole , valores , pfiscal.class == Array ? pfiscal.last : pfiscal)

            end

        end

        def procurar_td(string)

            txt = string.scan(/#{placa} [0-9]{9} #{@ano}/)

            if txt.length < 1

                @hash_conteudo[:erro] = "Não constam dados acerca da placa neste ano"

                return false

             else 

                return true

            end

        end

        def conteudo(nome , cpf , ncontrole , valores , posto_fiscal)

            depara = { "Americana" => "AMERICANA" , "Amparo" => "AMPARO" , "Andradina" => "ANDRADINA", "Aracatuba" => "ARAÇATUBA", "Araraquara" => "ARARAQUARA", "Assis" => "ASSIS", "Barretos" => "BARRETOS", "Barueri" => "BARUERI", "Bauru" => "BAURU", "Butanta" => "BUTANTÃ", "Campinas" => "CAMPINAS", "Catanduva" => "CATANDUVA", "Dracena" => "DRACENA", "Franca" => "FRANCA", "Guaratingueta" => "GUARATINGUETA", "Guarulhos" => "GUARULHOS", "Itapetininga" => "ITAPETININGA", "Itapeva" => "ITAPEVA", "Jales" => "JALES", "Jau" => "JAU", "Jundiai" => "JUNDIAI", "Lapa" => "LAPA", "Lapa/Santana" => "LAPA/SANTANA", "Limeira" => "LIMEIRA", "Lins" => "LINS", "Marilia" => "MARÍLIA", "Mogi das" => "MOGI DAS CRUZES", "Mogi-Guacu" => "MOGI GUAÇU", "Osasco" => "OSASCO", "Osvaldo" => "OSVALDO", "Ourinhos" => "OURINHOS", "Paulista" => "PAULISTA", "Penapolis" => "PENÁPOLIS", "Piracicaba" => "PIRACICABA", "Pirassununga" => "PIRASSUNUNGA", "Praia Grande" => "PRAIA GRANDE", "Pres Prudente" => "PRESIDENTE PRUDENTE", "Ribeirao" => "RIBEIRÃO PRETO", "Ribeirao Preto" => "RIBEIRÃO PRETO", "Rio Claro" => " RIO CLARO", "S J" => "SÃO JOSÉ", "Santo Andre" => "SANTO ANDRÉ", "Santos" => "SANTOS", "Sao Carlos" => "SÃO CARLOS", "Se" => "SÉ", "Sorocaba" => "SOROCABA", "SUZANO" => "SUZANO", "TATUAPE" => "TATUAPÉ", "Taubate" => "TAUBATÉ", "Votuporanga" => "VOTUPORANGA"}

            # ^^ depara para o filtro , acrescentar aqui a chave e valor ao hash com novas cidades

            filtro_depara = depara.map {|chave , valor| valor if posto_fiscal.match?(/#{chave}/) }.compact[0]

            # ^^ codigo que realiza o filtro com o depara

            @hash_conteudo = {
            nome: nome,
            cpf: cpf,
            ncontrole: ncontrole,
            ipva: valores[0],
            juros: valores[1],
            multa: valores[2],
            pfiscal: filtro_depara.nil? ? posto_fiscal : filtro_depara}

            # ^^ se o filtro der errado , força o retorno do texto sujo para inserção manual no depara

        end


        def pesquisar_pdf(url)

            puts "--------------------------------"
            puts "--------------------------------"
            puts "--------------------------------"
            puts ""
            puts "inicio pesquisa placa #{@placa} ano #{@ano} url :#{url}"
            puts ""
            puts "--------------------------------"
            puts "--------------------------------"
            puts "--------------------------------"

            if status_http(url) == "200"

                driver = Watir::Browser.new:firefox , headless: true

                # ^^ precisa abrir um uma instacia de navegador

                driver.goto url

                divs = driver.iframe(name: "GatewayPDF").present? ? driver.iframe(name: "GatewayPDF").text :  driver.frame(name: "GatewayCertificaPDF").text

                # força achar o iframe quando tem nome diferente

                driver.quit

                divs = divs.to_s.gsub("\n" , '|').split('|').join

                # ^ o texto vem tod  zuado,  precisa mudar \n por | para despois quebrar em array e juntar em stringona

                result_pesquisa = divs.scan(/[A-Z ÍÓÚÉÃÕÒÙÀÈÂ\D]{4,100} {0,21}[0-9]{1,14} {0,21}#{placa} {0,21}[0-9]{9} {0,21} {0,21}#{@ano} [ ]{0,21}[0-9]{1,6},[0-9]{2} {0,21}[0-9]{1,6},[0-9]{2} {0,21}[0-9]{1,6},[0-9]{2}[ ]{0,21}.{30}/)

                if result_pesquisa.length > 0

                    # Se achar o dado prepara os parametros para a funcao de retorno do conteudo assim como anteriormente quando não precisa abrir o pdf

                    nome = result_pesquisa.to_s.scan(/[A-Z ÍÓÚÉÃÕÒÙÀÈÂ\D]{4,100}/)[0].match(/[A-Z\W ]{4,100}$/)[0]
                    
                    cpf = result_pesquisa.to_s.scan(/[0-9]{14}/)[0]
                    
                    ncontrole = result_pesquisa.to_s.scan(/[0-9]{9}/)[1]
                    
                    valores = result_pesquisa.to_s.scan(/[0-9]{1,6},[0-9]{2}/)
                    
                    pfiscal = result_pesquisa.to_s.scan(/[A-Z][a-z]{1,10} [A-Z]{0,1}[a-z]{0,10}/)
                    
                    conteudo(nome , cpf , ncontrole , valores , pfiscal.class == Array ? pfiscal.last : pfiscal)
                    
                 else 

                    @hash_conteudo[:erro] = "erro no regex , tem informação coletar manualmente e contatar o desenvolverdor"

                end

                return @hash_conteudo

             else

                @hash_conteudo[:erro] = "404 , não foi possivel acessar a pagina do suplemento" 

             return @hash_conteudo

            end

        end

    end

end