require 'open-uri'
require 'nokogiri'
require 'json'
require 'sqlite3'


url = 'http://www.betexplorer.com/soccer/norway/eliteserien/fixtures/'


def get_rows(url)
  html = open(url)

  doc = Nokogiri::HTML(html)
  results = []
  table = doc.at_css('table.table-main')
  rows = table.css ('tr')


  # On each of the remaining rows

  fixtures_rows = rows.map do |row|

    # We get the name (<th>)
    column_name = row.css('th.h-text-left').map(&:text)


    # We get the text of each individual value (<td>)
    row_values = row.css('td').map(&:text)

    # We map the name, followed by all the values
    if row_values.size > 0
      [*row_values]
    elsif column_name.size > 0
      [*column_name]
    else
      nil
    end
  end

end

fixtures_rows = get_rows(url)

def map_rows(ary)
  round = 0
  date = ""
  ary.map do |row_as_text|
    if(row_as_text.size == 1)
      round = row_as_text[0].delete("^0-9") #Setting round
    end

    if(row_as_text.size > 1)
      date = row_as_text[0].empty? ?  date : row_as_text[0]
      row_as_text[0] = date
      teams = row_as_text[1].split('-')
      row_as_text[1] = teams[0].strip
      row_as_text[2] = teams[1].strip
      row_as_text[3] = ""
      row_as_text[4] = round.to_i
      row_as_text[6] = true

       row_as_text #return only when row contains match data
  end
end
end

fixtures_rows = get_rows(url)


fixtures_rows = map_rows(fixtures_rows)

fixtures_rows = fixtures_rows.select{ |item| !item.nil? } #Filter nils

p fixtures_rows

=begin


begin

    db = SQLite3::Database.new( "test_database.db" )
    puts db.get_first_value 'SELECT SQLITE_VERSION()'

    db.execute <<-SQL
    CREATE TABLE IF NOT EXISTS results (
       id INTEGER PRIMARY KEY,
      `match` VARCHAR,
      `home` INTEGER,
      `away` INTEGER,
      `u_o` VARCHAR,
      `g_ng` VARCHAR,
      `match_day` DATE,
      `valid` BOOLEAN,
      `round` INTEGER
    );
  SQL

  fixtures_rows.each do |match|
    db.execute("INSERT INTO results ('match', 'home', 'away', 'u_o', 'g_ng', 'match_day', 'valid', 'round')
            VALUES (?, ?, ?, ?, ?, ?, ?, ?)", [match[0], match[1], match[2], match[3], match[4], match[5], match[6] ? 1: 0, match[7]])
  end

rescue SQLite3::Exception => e

    puts "Exception occurred"
    puts e

ensure
    db.close if db
end




=end
