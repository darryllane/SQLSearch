#SQLSearch


#Dependencies
require "tiny_tds"		#Microsoft SQL Database connection gem
require "colorize"		#String shell output colouring module
require "trollop"		#Commandline options parser



#Commandline Parsing with Trollop
opts = Trollop::options do
version "SQLSearch 1.0"
banner <<-EOS

SQLSearch v1.0
This tool is used to help security consultants locate potentially
sensitive information in Microsoft SQL databases. The table and
column names are extracted from the database and are compared with
a list of keywords.

Example Usage:

$ruby sqlsearch.rb -w -u administrator -p Pa55w0rd -d WORKGROUP -t 10.0.0.1 -o output.txt
   
EOS
  opt :username, "SA/Windows Username", :type => :string      # Username for database connection
  opt :password, "SA/Windows Password", :type => :string      # Password for database connection
  opt :domain, "Windows Domain Name", :type => :string     		  # Domain for use with Windows auth connection
  opt :wauth, "Use Windows Authentication"                    # flag --monkey, default false
  opt :target, "Target Database IP Address/Hostname", :type => :string     	  # Target IP Address
  opt :database, "Target a single database", :type => :string     	  # Target IP Address
  opt :sample, "Output sample data from matches"			  # Select rows from matched tables
  opt :depth, "Sample data depth. Max: 10", :default => 1   			  # Quantity of rows to return from sampling
  opt :query, "Show example SQL queries"                  			  # Show example SQL queries
  opt :output, "Output matches to file", :type => :string      # Output matches to a file
end



#Read in keywords from file.
keywords = []
keywordfile = File.new("keywords.txt", "r")
keywordfile.each do |keyword|
keywords.push(keyword.to_s.gsub("\n",""))
end

#Create a client Tiny_TDS Windows auth database object
def createclient(username,password,domain,targetaddress)
	client = TinyTds::Client.new(:username => "#{domain}\\#{username}",:password => "#{password}", :dataserver => "#{targetaddress}")
	end

#Create a client Tiny_TDS SQL auth database object
def createclientsql(username,password,targetaddress)
	client = TinyTds::Client.new(:username => "#{username}",:password => "#{password}", :dataserver => "#{targetaddress}")
	end



#Test the connection to the server

#Windows Authentication
begin
if opts[:wauth]

	client = createclient(opts[:username],opts[:password],opts[:domain],opts[:target])
		if client.active? == true
			puts ""
			puts "=> Successfully connected to " + opts[:target].to_s + " with " + opts[:username].to_s + "/" + opts[:password].to_s
			
		else
			puts "X There were connection problems, check your settings."
		end
#end


#SQL Authentication
else
	client = createclientsql(opts[:username],opts[:password],opts[:target])
		if client.active? == true
			puts ""
			puts "=> Successfully connected to " + opts[:target].to_s + " with " + opts[:username].to_s + "/" + opts[:password].to_s
			
		else
			puts "X There were connection problems, check your settings."
		end
end
rescue
	puts ""
	puts "X> Connection to the database failed. Please check your settings."
	puts ""
	abort()
end

#Query the SQL server version
result = client.execute("SELECT @@VERSION")
	if result.each[0][""].include?("Server 2005")
	puts "=> Banner: Microsoft SQL Server 2005"
	
	elsif result.each[0][""].include?("Server 2008")
	puts "=> Banner: Microsoft SQL Server 2008"
	elsif result.each[0][""].include?("Server 2012")
	puts "=> Banner: Microsoft SQL Server 2012"
	elsif result.each[0][""].include?("Server 2000")
	puts "=> Banner: Microsoft SQL Server 2000"
	else
	puts "Unknown Version"
	end



#Query the master databases
result = client.execute("SELECT name FROM Master.dbo.sysdatabases")
masterdbs = []
count = 0
while count < result.count do
	masterdbs.push(result.each[count]["name"])
	count += 1
	end
masterdbs.delete("master")
masterdbs.delete("tempdb")
masterdbs.delete("model")
masterdbs.delete("msdb")
puts "=> Enumerated " + masterdbs.count.to_s + " non-default databases."

puts "=> Found: #{masterdbs.join(", ")}"

puts ""





#Cycle each master database, add each master db as a key to finalhash with tables as values

finalhash = {}
masterdbs.each do |mds|
	finalhash[mds] = {}
end


#Single database option
if opts[:database]
	masterdbs = [opts[:database]]
	finalhash = {}
	finalhash[opts[:database]] = {}
end





#----------------------------------------------
# Building the database information hash
#----------------------------------------------

masterdbs.each do |mds|

	
	#Select table names from the database with tiny_tds
	begin
	result = client.execute("SELECT TABLE_NAME FROM " + mds + ".INFORMATION_SCHEMA.TABLES")
	rescue
		puts "Issues connecting to the " + mds + " database. Could be lack of privileges."
		masterdbs.delete(mds)
		puts mds + " Removed..."
	end


	#Extract table names from the tiny_tds object and insert them as keys in the final hash
	currenttablelist = []
	count = 0
	while count < result.each.count do

		currenttablelist.push(result.each[count]["TABLE_NAME"])
		count += 1
		result.cancel

	end
	currenttablelist.each do |table|
		finalhash[mds][table] = {}
	end


	#Select column names from the database with tiny_tds
	currenttablelist.each do |table|

	columnlist = []

	result = client.execute("SELECT * FROM " + mds + ".INFORMATION_SCHEMA.COLUMNS WHERE TABLE_NAME = '" + table + "'")



	#Extract column names from the tiny_tds object and insert them as values to the table keys in the final hash
		count = 0
		while count < result.each.count do
			columnlist.push(result.each[count]["COLUMN_NAME"])
			count += 1
		result.cancel
		end	

	finalhash[mds][table] = columnlist

	end
end	


#------------------------------------------------------
# Searching the database information hash for keywords
#------------------------------------------------------


masterdbs.each do |mds|

	finalhash[mds].each do |table, column|

		keywords.each do |keyword|

			if keyword.to_s == table.to_s
				result = client.execute("SELECT TOP 10 * FROM " + mds.to_s + ".dbo.[" + table.to_s + "]")
				if result.count > 0
					puts "=> " + "Match Found!".yellow + " >" + keyword.to_s.upcase.white + "< table found in the " + mds.to_s.upcase.yellow + " database."
					

					#Output queries to screen
					if opts[:query]
						puts "Query: SELECT TOP 10 * FROM " + mds + ".dbo.[" + table+ "];"	
						puts ""
					else
						puts ""
					end	

					#Output sample data to screen
					if opts[:sample]

						maxdepth = opts[:depth].to_i
						upperdepth = result.each.count

						count = 0
						
						while (count < upperdepth) && (count < maxdepth)

							puts "Row" + (count + 1).to_s + " " + result.each[count].values.join(", ")
							count += 1
						end
						puts ""
					end

					#Output matches to file
					if opts[:output]

						File.open(opts[:output].to_s,'a') do |file|
						file.write(mds.to_s + " > " + table.to_s + "\n")
						end
					end


				end
				result.cancel

			elsif column.include?(keyword)
				result = client.execute("SELECT TOP 10 " + keyword.to_s + " FROM " + mds.to_s + ".dbo.[" + table.to_s + "]")
				if result.count > 0
					puts "=> " + "Match Found!".yellow + " >" + keyword.to_s.upcase.white + "< column found in the " + table.to_s.upcase.yellow + " table in the " + mds.to_s.upcase.yellow + " database."
					
					#Output queries to screen
					if opts[:query]
						puts "Query: SELECT TOP 10 " + keyword.to_s.upcase + " FROM " + mds + ".dbo.[" + table + "];"
						puts ""		
					else
						puts ""
					end


					#Output sample data to screen
					if opts[:sample]

					maxdepth = opts[:depth].to_i
					upperdepth = result.each.count

					count = 0
						
					while (count < upperdepth) && (count < maxdepth)

						puts "Row" + (count + 1).to_s + " " + result.each[count].values.join(", ")
						count += 1
					end
						puts ""
					end

					#Output matches to file
					if opts[:output]

						File.open(opts[:output].to_s,'a') do |file|
						file.write(mds.to_s + " > " + table.to_s + " > " + keyword.to_s + "\n")
						end
					end

				end
				result.cancel

			end

		end

	end

end













