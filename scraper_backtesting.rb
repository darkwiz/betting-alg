require 'open-uri'
require 'nokogiri'
require 'json'

url = 'http://www.betexplorer.com/soccer/norway/eliteserien/results/'
fixtures = 'http://www.betexplorer.com/soccer/norway/eliteserien/results/'
day_matches_no = 9
#http://www.betexplorer.com/soccer/japan/j-league-division-2/results/'
#fixtures = 'http://www.betexplorer.com/soccer/japan/j-league-division-2/fixtures/'

def get_rows(url)
  html = open(url)

  doc = Nokogiri::HTML(html)
  results = []
  table = doc.at_css('table.table-main')
  rows = table.css ('tr')

  #column_names = rows.shift.css('th.h-text-left').map(&:text)



  # On each of the remaining rows
  all_rows = rows.map do |row|

    # We get the name (<th>)
    #row_name = row.css('th').text

    # We get the text of each individual value (<td>)
    row_values = row.css('td').map(&:text)

    # We map the name, followed by all the values
    [*row_values]
  end
end

def filter_by_team(ary, team)
  filtered = []

  ary.each do |res|
    if(res[6] == true) #valid results only
      if res[0] == team
       filtered.push({ :home => true,  :gf => res[2][:home], :gs => res[2][:away], :u_o => res[3], :g_ng => res[4],:date => res[5]})
     end
     if res[1] == team
      filtered.push({ :home => false, :gf => res[2][:away] , :gs => res[2][:home], :u_o => res[3], :g_ng => res[4],:date => res[5]})
    end
  end
end
  #p filtered
  filtered
end

def compute_counters(matches, counters, playing_home)
  matches.each_with_index do |match, index|
   counters[:under] += match[:u_o].eql?('under') ? 1 : 0
   counters[:over] += match[:u_o].eql?('over') ? 1 : 0
   if(index == 4)
    counters[:under_last_5] = counters[:under]
    counters[:over_last_5] = counters[:over]
  end
  counters[:home_away_under] += match[:u_o].eql?('over') ? 1 : 0 if match[:home] == playing_home
  counters[:home_away_over] += match[:u_o].eql?('over') ? 1 : 0 if match[:home] == playing_home
  counters[:scored] += match[:gf]
  counters[:conceded] += match[:gs]
  counters[:home_away_scored] += match[:gf] if match[:home] == playing_home
  counters[:home_away_conceded] += match[:gs] if match[:home] == playing_home
end
counters
end

def under_over_stats(data, played, target_event)
  if(target_event == 'under')
    a = data[:under] / played
    b = data[:home_away_under] / played
    c = data[:under_last_5] / 5
  else
    a = data[:over] / played
    b = data[:home_away_over] / played
    c = data[:over_last_5] / 5
  end
  d = (a + b + c) / 3 * 100
end

def init_counters(counters)
  counters[:under] = 0.0
  counters[:over] = 0.0
  counters[:home_away_under] = 0.0
  counters[:home_away_over] = 0.0
  counters[:scored] = 0.0
  counters[:home_away_scored] = 0.0
  counters[:conceded] = 0.0
  counters[:home_away_conceded] = 0.0

  counters[:under_last_5] = 0.0
  counters[:over_last_5] = 0.0
end

def map_rows(ary, type)
  type == 'fixtures' ? index = 1 : index = 0
  ary.each do |row_as_text|
    if(row_as_text.empty? == false)
      teams = row_as_text[0].split('-')
      if(type == 'results')
        row_as_text[6] =  !!(row_as_text[1] =~ /^\d+:\d+$/)
        row_as_text[2] = {
         :home => row_as_text[1].split(':')[0].to_i,
         :away => row_as_text[1].split(':')[1].to_i
       }
       row_as_text[0] = teams[0].strip
       row_as_text[1] = teams[1].strip

       row_as_text[3] = row_as_text[2][:home] + row_as_text[2][:away] > 2 ? "over" : "under"
       row_as_text[4] = row_as_text[2][:home] == 0 || row_as_text[2][:away] == 0 ? "nogoal" : "goal"
     else
      row_as_text[0] = teams
      row_as_text[1] = teams[0].strip
      row_as_text[2] = teams[1].strip
      row_as_text[3] = ""
      row_as_text[4] = ""
      row_as_text[6] = true
    end

  end
end
end


all_rows = get_rows(url) #results
matches_rows = get_rows(fixtures) # match day



matches_rows = map_rows(matches_rows[day_matches_no * 2 + 1 , day_matches_no * 3] , 'fixtures')
all_rows.shift(3)
all_rows = map_rows(all_rows, 'results')

p all_rows
p matches_rows


matches_rows.first(day_matches_no).each do |item|
  home_team_to_analyze = item[1]

  away_team_to_analyze = item[2]


  home_team_matches = filter_by_team(all_rows, home_team_to_analyze)
  home_team_played = home_team_matches.count

  away_team_matches = filter_by_team(all_rows, away_team_to_analyze)
  away_team_played = away_team_matches.count

  counters = {}
  init_counters(counters)
  data_home = compute_counters(home_team_matches, counters, true)
  target_event_res_home_under = under_over_stats(data_home, home_team_played, 'under')

  target_event_res_home_over = under_over_stats(data_home, home_team_played, 'over')

  init_counters(counters)
  data_away = compute_counters(away_team_matches, counters, false)

  target_event_res_away_under = under_over_stats(data_away, away_team_played, 'under')

  target_event_res_away_over = under_over_stats(data_away, away_team_played, 'over')

  goal_diff_avg_1 =  (data_home[:conceded] - data_away[:scored] ) / home_team_played
  item[3] = (target_event_res_home_over + target_event_res_away_over) / 2
  item[4] = (target_event_res_home_under + target_event_res_away_under) / 2
  item[5] = goal_diff_avg_1
end


p "Match \t Over \t Under \t AVG \n"
matches_rows.first(day_matches_no).each do |match|
  unless(match[0].nil?)
    the_match = match[0].join("-")
    p " #{the_match} \t #{match[3]}% \t #{match[4]}% \t #{match[5]} \n"
  end
end


#json = JSON.pretty_generate(results)
#File.open("data.json", 'w') { |file| file.write(json) }
