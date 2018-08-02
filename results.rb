require 'open-uri'
require 'nokogiri'
require 'json'
require 'sqlite3'


url = 'http://www.betexplorer.com/soccer/norway/eliteserien/results/'


def get_rows(url)
  html = open(url)

  doc = Nokogiri::HTML(html)
  results = []
  table = doc.at_css('table.table-main')
  rows = table.css ('tr')


  # On each of the remaining rows

  results_rows = rows.map do |row|

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

results_rows = get_rows(url)

def map_rows(ary)
  round = 0
  ary.map do |row_as_text|
    if(row_as_text.size == 1)
      round = row_as_text[0].delete("^0-9") #Setting round
    end

    if(row_as_text.size > 1)
       teams = row_as_text[0].split('-')
       result_splitted = row_as_text[1].split(':')
       row_as_text[6] =  !!(row_as_text[1] =~ /^\d+:\d+$/)
       row_as_text[2] = row_as_text[1] #result non-splitted
       row_as_text[0] = teams[0].strip #home
       row_as_text[1] = teams[1].strip #away

       row_as_text[3] = result_splitted[0].to_i + result_splitted[1].to_i > 2 ? "over" : "under"
       row_as_text[4] = result_splitted[0].to_i == 0 || result_splitted[1].to_i == 0 ? "nogoal" : "goal"
       row_as_text[7] = round.to_i

       row_as_text #return only when row contains match data
  end
end
end

results_rows = get_rows(url)


results_rows = map_rows(results_rows)

results_rows = results_rows.select{ |item| !item.nil? } #Filter nils



begin

    db = SQLite3::Database.new( "test_database.db" )
    puts db.get_first_value 'SELECT SQLITE_VERSION()'

    db.execute <<-SQL
    CREATE TABLE IF NOT EXISTS results (
       id INTEGER PRIMARY KEY,
      `home` VARCHAR,
      `away` VARCHAR,
      `result` VARCHAR,
      `u_o` VARCHAR,
      `g_ng` VARCHAR,
      `match_day` DATE,
      `valid` BOOLEAN,
      `round` INTEGER
    );
  SQL

  results_rows.each do |match|
    db.execute("INSERT INTO results ( 'home', 'away', 'result', 'u_o', 'g_ng', 'match_day', 'valid', 'round')
            VALUES (?, ?, ?, ?, ?, ?, ?, ?)", [match[0], match[1], match[2], match[3], match[4], match[5], match[6] ? 1: 0, match[7]])
  end

rescue SQLite3::Exception => e

    puts "Exception occurred"
    puts e

ensure
    db.close if db
end




