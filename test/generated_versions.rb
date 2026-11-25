require 'cgi'

%w[setup 1.x/setup 2.x/setup].each do |page|
  path = "build/documentation/#{page}.html"
  html = File.read(path)
  text = CGI.unescapeHTML(html.gsub(/<[^>]*>/, ''))

  library = text.match(/"org\.scalikejdbc"\s*%%\s*"scalikejdbc"\s*%\s*"([^"]+)"/)
  plugin = text.match(/addSbtPlugin\("org\.scalikejdbc"\s*%%\s*"scalikejdbc-mapper-generator"\s*%\s*"([^"]+)"\)/)

  abort "#{path}: missing or mismatched ScalikeJDBC and mapper generator versions" unless
    library && plugin && library[1] == plugin[1]
end
