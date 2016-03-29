#!/usr/bin/env ruby

#SQLSearch


#Dependencies
require "tiny_tds"		#Microsoft SQL Database connection gem
require "colorize"		#String shell output colouring module
require "trollop"		#Commandline options parser
require "text-table"	#Outputs sample data in table form to terminal
require "net/ping"		#Used to test connection server before database



#Commandline Parsing with Trollop
opts = Trollop::options do
version "SQLSearch 2.5.2"
banner <<-EOS

SQLSearch v1.0
A tool used to help security consultants locate potentially
sensitive information in Microsoft SQL databases. The table and
column names are extracted from the database and are compared with
a list of keywords using regex.

Example Usage:

$ruby sqlsearch.rb -w -u administrator -p Pa55w0rd -d WORKGROUP -t 10.0.0.1 -o output.txt
   
EOS
  opt :username, "SA/Windows Username", :type => :string      
  opt :password, "SA/Windows Password", :type => :string      
  opt :domain, "Windows Domain Name", :type => :string     		  
  opt :target, "Target Server IP Address/Hostname", :type => :string     	  
  opt :database, "Target a Single Database", :type => :string     	 
  opt :port, "Target Port", :default => 1433
  opt :keyword, "Specify Specific Keyword (Ignores keywords.txt)", :type => :string
  opt :sample, "Output Sample Data from Matches"			 
  opt :depth, "Sample Data Depth. Max: 10", :default => 1   			 
  opt :truncate, "Truncate Sample Data", :default => 64
  opt :rowcount, "Minimum Row Count", :default => 1   			 
  opt :query, "Show Example SQL Queries"     
  opt :hide, "Hide Warning Messages"              			
  opt :export, "Output Matches to CSV File", :type => :string      

end


#Create Output File
if opts[:export]
	File.open(opts[:export].to_s,'a') do |file|
	file.write("DATABASE,SCHEMA,TABLE,COLUMN,ROWCOUNT\n")
	end
end


#Read in keywords from file.
if opts[:keyword]
	keywords = []
	keywords.push(opts[:keyword])
else
	keywords = []
	keywordfile = File.new("keywords.txt", "r")
	keywordfile.each do |keyword|
	keywords.push(keyword.to_s.gsub("\n",""))
	end
end


#Test connection to server
live = Net::Ping::TCP.new(opts[:target],opts[:port],1)
	if live.ping? == true
		print "\n=> Server connection successful to " + opts[:target].to_s + ":" + opts[:port].to_s
	else
		puts "\n=> Server connection failed to " + opts[:target].to_s + ":" + opts[:port].to_s + "\n\n"
		abort()
	end




#Create Tiny_TDS client
begin
if opts[:domain]
	client = TinyTds::Client.new(:username => opts[:domain] + "\\" + opts[:username],:password => opts[:password], :host => opts[:target], :port => opts[:port], :timeout => 10)
else
	client = TinyTds::Client.new(:username => opts[:username],:password => opts[:password], :host => opts[:target], :port => opts[:port], :timeout => 10)
end
rescue
	puts "\n=> Connection to the database failed. Please check your syntax and credentials.\n".red
	abort()
end



#Confirm server connection
if client.active? == true
	puts ""
	puts "=> Database connection successful with " + opts[:username].to_s + "/" + opts[:password].to_s
			
else
	abort "X There were connection problems, check your settings."

end



#Query the SQL server version
result = client.execute("SELECT @@VERSION")
if result.each[0][""].include?("2000")
	puts "=> Banner: Microsoft SQL Server 2000"
elsif result.each[0][""].include?("Server 2005")
	puts "=> Banner: Microsoft SQL Server 2005"
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
	begin
	result = client.execute("SELECT name FROM master.dbo.sysdatabases")
	result.each
	masterdbs = []
	count = 0
	while count < result.count do
		masterdbs.push(result.each[count]["name"])
		count += 1
		end
	masterdbs.delete("master") ; masterdbs.delete("tempdb") ; masterdbs.delete("model") ; masterdbs.delete("msdb")
	puts "=> Enumerated " + masterdbs.count.to_s + " non-default databases."
	puts "=> Found: #{masterdbs.join(", ")}\n"

	#Cycle each master database, add each master db as a key to finalhash with tables as values
	finalhash = {}
	masterdbs.each do |mds|
	finalhash[mds] = {}
	end
	rescue
		result.each
		result.cancel
		puts "=> Warning! Unable to enumerate master databases. Database version may be too old.".red
		abort()
	end
end


#----------------------------------------------
# Confirm access to each database
#----------------------------------------------
masterdbs.each do |mds|

	begin
	result = client.execute("SELECT DISTINCT TABLE_SCHEMA FROM " + mds.to_s + ".INFORMATION_SCHEMA.TABLES")
	result.each

	rescue
		if !opts[:hide]
			result.cancel
			puts "=> Could not access the ".red + mds.to_s.upcase.yellow + "< database. Could be lack of privileges.".red
			puts "   Try using local administator or SA credentials.".red
			masterdbs.delete(mds)
		else
			result.cancel
			masterdbs.delete(mds)
		end
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
				puts "=> Issues connecting to the >".red + mds.to_s.upcase.yellow + "< database. Could be lack of privileges.".red
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

			begin
			result = client.execute("SELECT COLUMN_NAME FROM " + mds + ".INFORMATION_SCHEMA.COLUMNS WHERE TABLE_NAME = '" + table + "' AND TABLE_SCHEMA='" + schema + "'")
			result.each
			rescue
				result.cancel
				puts "=> Issues connecting to the >".red + table.to_s.upcase.yellow + "< database. Could be lack of privileges.".red
				puts "   Try using local administator or SA credentials.".red
				currenttablelist.delete(table)
				puts ""
			end

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
				begin
					client.execute("SET ANSI_NULLS, QUOTED_IDENTIFIER, CONCAT_NULL_YIELDS_NULL, ANSI_WARNINGS, ANSI_PADDING ON;")
					result = client.execute("SELECT COUNT(*) FROM [" + mds.to_s + "].[" + schema.to_s + "].[" + tablename.to_s + "]")
				rescue
					puts "Unable to connect to " + tablename.to_s
				end

				rowcount = 0
				if (result.each[0][""]) > opts[:rowcount].to_i	
				rowcount = (result.each[0][""]).to_i

				
				puts "Match! '" + keyword.to_s.green + "' | " + mds.to_s.yellow + " > " + schema.to_s.yellow + " > " + tablename.to_s.yellow + " | Rows:".yellow + (result.each[0][""]).to_s


					#Output queries to screen
					if opts[:query]
					puts "Query: SELECT TOP 10 * FROM [" + mds.to_s + "].[" + schema.to_s + "].[" + tablename.to_s + "];"	
					puts ""
					else
					puts ""
					end	

					#Output sample data to screen
					if opts[:sample]

					outputtable = Text::Table.new

					result = client.execute("SELECT TOP 10 *  FROM [" + mds.to_s + "].[" + schema.to_s + "].[" + tablename.to_s + "]")

					maxdepth = opts[:depth].to_i
					upperdepth = result.each.count

					count = 0

					outputtable.head = table[tablename]
								
					while (count < upperdepth) && (count < maxdepth)

					#Truncate large data values
					tempvalues = result.each[count].values
					tempvalues.map! { |value|
						if(value.to_s.length > opts[:truncate])
							"TRUNCATED"
						else
							value
						end
					}

					outputtable.rows << tempvalues
					count += 1

					#Truncate large data values


					end
					puts outputtable.to_s
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
						puts "Unable to connect to " + item.to_s
					end
					rowcount = 0
					
					begin
					if (result.each[0][""]) > opts[:rowcount].to_i
					rowcount = (result.each[0][""]).to_i
					
					puts "Match! '" + keyword.to_s.green + "' | " + mds.to_s.yellow + " > " + schema.to_s.yellow + " > " + tablename.to_s.yellow + " > " + item.to_s.yellow + " | Rows:".yellow + (result.each[0][""]).to_s


					#Output queries to screen
					if opts[:query]
					puts "Query: SELECT TOP 10 [" + item.to_s + "] FROM [" + mds.to_s + "].[" + schema.to_s + "].[" + tablename.to_s + "];"	
					puts ""
					else
					puts ""
					end	

					#Output samples to screen
					if opts[:sample]

					outputtable2 = Text::Table.new

					result = client.execute("SELECT TOP 10 * FROM [" + mds.to_s + "].[" + schema.to_s + "].[" + tablename.to_s + "]")

					maxdepth = opts[:depth].to_i
					upperdepth = result.each.count

					outputtable2.head = table[tablename]

					count = 0
								
					while (count < upperdepth) && (count < maxdepth)

					#Truncate large data values
					tempvalues = result.each[count].values
					tempvalues.map! { |value|
						if(value.to_s.length > opts[:truncate])
							"TRUNCATED"
						else
							value
						end
					}

					outputtable2.rows << tempvalues
					count += 1
					end
					puts outputtable2.to_s
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
						result.each
						if !opts[:hide]
							puts "WARNING! Could not access ".red + mds.to_s.red + " > " + schema.to_s.red + " > " + tablename.to_s.red + " > " + item.to_s.red + "\n\n"
						end
						
					end

					end
					
				end

			end

		end

	end

end