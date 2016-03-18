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
  opt :target, "Target Server IP Address/Hostname", :type => :string     	  # Target IP Address
  opt :hostfile, "Target Hosts File", :type => :string     	  # Target Hosts File
  opt :database, "Target a Single Database", :type => :string     	  # Target IP Address
  opt :port, "Target Port", :default => 1433
  opt :sample, "Output Sample Data from Matches"			  # Select rows from matched tables
  opt :depth, "Sample Data Depth. Max: 10", :default => 1   			  # Quantity of rows to return from sampling
  opt :rowcount, "Minimum Rows", :default => 1   			  # Quantity of rows to return from sampling
  opt :query, "Show Example SQL Queries"                  			  # Show example SQL queries
  opt :export, "Output Matches CSV File", :type => :string      # Output matches to a file

end


#Create Output File
if opts[:export]
	File.open(opts[:export].to_s,'a') do |file|
	file.write("DATABASE,SCHEMA,TABLE,COLUMN,ROWCOUNT\n")
	end
end


#Read in keywords from file.
keywords = []
keywordfile = File.new("keywords.txt", "r")
keywordfile.each do |keyword|
keywords.push(keyword.to_s.gsub("\n",""))
end




#Create Tiny_TDS client
begin
if opts[:domain]
	client = TinyTds::Client.new(:username => opts[:domain] + "\\" + opts[:username],:password => opts[:password], :host => opts[:target], :port => opts[:port], :timeout => 2)
else
	client = TinyTds::Client.new(:username => opts[:username],:password => opts[:password], :host => opts[:target], :port => opts[:port], :timeout => 2)
end
rescue
	puts ""
	abort("X> Connection to the database failed. Please check your syntax and credentials.")
	puts ""
end



#Confirm server connection
if client.active? == true
	puts ""
	puts "=> Successfully connected to " + opts[:target].to_s + " with " + opts[:username].to_s + "/" + opts[:password].to_s
			
else
	abort "X There were connection problems, check your settings."

end



#Query the SQL server version
result = client.execute("SELECT @@VERSION")
if result.each[0][""].include?("Server 2000")
	puts "=> Banner: Microsoft SQL Server 2000"
elsif result.each[0][""].include?("Server 2003")
	puts "=> Banner: Microsoft SQL Server 2003"
elsif result.each[0][""].include?("Server 2008")
	puts "=> Banner: Microsoft SQL Server 2008"
elsif result.each[0][""].include?("Server 2012")
	puts "=> Banner: Microsoft SQL Server 2012"
else
	puts "Unknown Version"
end


#Single database option or enumerate all databases
if opts[:database]
	masterdbs = [opts[:database]]
	finalhash = {}
	finalhash[opts[:database]] = {}
else
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
end



#----------------------------------------------
# Building the database information hash
#----------------------------------------------

masterdbs.each do |mds|


	#Extract the schemas
	result = client.execute("SELECT DISTINCT TABLE_SCHEMA FROM " + mds.to_s + ".INFORMATION_SCHEMA.TABLES")

	schemalist = []
	count = 0
	while count < result.each.count do
		schemalist.push(result.each[count]["TABLE_SCHEMA"])
		count += 1
		result.cancel
	end


	schemalist.each do |schema|

	
			#Select table names from the database with tiny_tds
			begin
			
			result = client.execute("SELECT TABLE_NAME FROM " + mds.to_s + ".INFORMATION_SCHEMA.TABLES WHERE TABLE_SCHEMA='" + schema.to_s + "'")
			result.each

			rescue
				result.cancel
				puts "=> Issues connecting to the >".red + mds.to_s.upcase.white + "< database. Could be lack of privileges.".red
				puts "   Try using local administator or SA credentials.".red
				masterdbs.delete(mds)
				puts ""
			end

			#Add Schemas to final hash

			finalhash[mds][schema] = {}


			#Extract table names from the tiny_tds object and insert them as keys in the final hash
			currenttablelist = []
			count = 0
			while count < result.each.count do

				currenttablelist.push(result.each[count]["TABLE_NAME"])
				count += 1
				result.cancel

			end

			currenttablelist.each do |table|
				finalhash[mds][schema][table] = {}
			end



			#Select column names from the database with tiny_tds
			currenttablelist.each do |table|

			columnlist = []

			result = client.execute("SELECT COLUMN_NAME FROM " + mds + ".INFORMATION_SCHEMA.COLUMNS WHERE TABLE_NAME = '" + table + "' AND TABLE_SCHEMA='" + schema + "'")


			#Extract column names from the tiny_tds object and insert them as values to the table keys in the final hash
				count = 0
				while count < result.each.count do
					columnlist.push(result.each[count]["COLUMN_NAME"])
					count += 1
				result.cancel
				end	

			finalhash[mds][schema][table] = columnlist

			end


		end


end	


#------------------------------------------------------
# Searching the database information hash for keywords
#------------------------------------------------------

puts ""
puts "Searching Table Names..."
puts ""
#Searching for table matches

masterdbs.each do |mds|

	keywords.each do |keyword|

		finalhash[mds].each do |schema, table|

			table.each do |tablename, column|

				if tablename.to_s.match(/#{keyword}/i)

				#Check Row Count
					client.execute("SET ANSI_NULLS, QUOTED_IDENTIFIER, CONCAT_NULL_YIELDS_NULL, ANSI_WARNINGS, ANSI_PADDING ON;")
					result = client.execute("SELECT COUNT(*) FROM [" + mds.to_s + "].[" + schema.to_s + "].[" + tablename.to_s + "]")

				rowcount = 0
				if (result.each[0][""]) > opts[:rowcount].to_i	
				rowcount = (result.each[0][""]).to_i

				
				puts "Match! '" + keyword.to_s.yellow + "' | " + mds.to_s.white + " > " + schema.to_s.white + " > " + tablename.to_s.white + " | Rows:".white + (result.each[0][""]).to_s


					#Output queries to screen
					if opts[:query]
					puts "Query: SELECT TOP 10 * FROM [" + mds.to_s + "].[" + schema.to_s + "].[" + tablename.to_s + "];"	
					puts ""
					else
					puts ""
					end	

					#Output sample data to screen
					if opts[:sample]

					result = client.execute("SELECT TOP 10 *  FROM [" + mds.to_s + "].[" + schema.to_s + "].[" + tablename.to_s + "]")

					maxdepth = opts[:depth].to_i
					upperdepth = result.each.count

					count = 0

					puts table[tablename].join(", ")
								
					while (count < upperdepth) && (count < maxdepth)

					puts "Row" + (count + 1).to_s + " " + result.each[count].values.join(", ")
					count += 1
					end
					puts ""

					end

					#Output matches to file
					if opts[:export]

						File.open(opts[:export].to_s,'a') do |file|
						file.write(mds.to_s + "," + schema.to_s + "," + tablename.to_s + ",Column" + "," + rowcount.to_s + "\n")
						end
					end





						

					end

				end

			end

		end

	end

end

puts ""
puts "Searching Columns Names..."
puts ""
#Searching for column matches


masterdbs.each do |mds|
	
	keywords.each do |keyword|

		finalhash[mds].each do |schema, table|

			table.each do |tablename, column|

				column.each do |item|

					if item.to_s.match(/#{keyword}/i)

					begin
					#Check Row Count
					client.execute("SET ANSI_NULLS, QUOTED_IDENTIFIER, CONCAT_NULL_YIELDS_NULL, ANSI_WARNINGS, ANSI_PADDING ON;")
					result = client.execute("SELECT COUNT([" + item + "]) FROM [" + mds.to_s + "].[" + schema.to_s + "].[" + tablename.to_s + "]")
					rescue
						puts "Something went wrong here"
					end
					rowcount = 0
					
					begin
					if (result.each[0][""]) > opts[:rowcount].to_i
					rowcount = (result.each[0][""]).to_i
					
					puts "Match! '" + keyword.to_s.yellow + "' | " + mds.to_s.white + " > " + schema.to_s.white + " > " + tablename.to_s.white + " > " + item.to_s.white + " | Rows:".white + (result.each[0][""]).to_s


					#Output queries to screen
					if opts[:query]
					puts "Query: SELECT TOP 10 [" + item.to_s + "] FROM [" + mds.to_s + "].[" + schema.to_s + "].[" + tablename.to_s + "];"	
					puts ""
					else
					puts ""
					end	

					#Output samples to screen
					if opts[:sample]

					result = client.execute("SELECT TOP 10 * FROM [" + mds.to_s + "].[" + schema.to_s + "].[" + tablename.to_s + "]")

					maxdepth = opts[:depth].to_i
					upperdepth = result.each.count

					puts table[tablename].join(", ")

					count = 0
								
					while (count < upperdepth) && (count < maxdepth)

					puts "Row" + (count + 1).to_s + " " + result.each[count].values.join(", ")
					count += 1
					end
					puts ""

					end

					#Output matches to file
					if opts[:export]

						File.open(opts[:export].to_s,'a') do |file|
						file.write(mds.to_s + "," + schema.to_s + "," + tablename.to_s + "," + item.to_s + "," + rowcount.to_s + "\n")
						end
					end



					end

					rescue
						
					end

					end
					
				end

			end

		end

	end

end