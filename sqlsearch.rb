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
version "SQLSearch 3.2.4"
banner <<-EOS    

   ____ ____    __    ____ ____ ___    ___   _____ __ __
  / __// __ \\  / /   / __// __// _ |  / _ \\ / ___// // /
 _\\ \\ / /_/ / / /__ _\\ \\ / _/ / __ | / , _// /__ / _  / 
/___/ \\___\\_\\/____//___//___//_/ |_|/_/|_| \\___//_//_/  
                                                                                      
v3.2.4

Example Usage:

$ruby sqlsearch.rb -u administrator -p Pa55w0rd -d WORKGROUP -t 10.0.0.1 -x output.csv
   
EOS
  opt :username, "SA/Windows Username", :type => :string      
  opt :password, "SA/Windows Password", :type => :string      
  opt :domain, "Windows Domain Name", :type => :string     		  
  opt :target, "Target Server IP Address/Hostname", :type => :string     	  
  opt :database, "Target a Single Database (will not enumerate all databases)", :type => :string     	 
  opt :port, "Target Port", :default => 1433
  opt :keyword, "Specify Specific Keyword (Ignores keywords.txt)", :type => :string
  opt :sample, "Output Sample Data from Matches"			 
  opt :depth, "Sample Data Depth. Max: 10", :default => 1   			 
  opt :truncate, "Truncate Sample Data", :default => 64
  opt :rowcount, "Minimum Row Count", :default => 1   			 
  opt :verbose, "Show Verbose Output"
  opt :statistics, "Show Statistics"              			
  opt :export, "Output Matches to CSV File", :type => :string      

end


#Check User Syntax
unless opts[:username] && opts[:password] && opts[:target]
	puts "Please specify a username (-u), a password (-p) and a target host (-t)".red
	abort()
end



class EnumerateDatabaseStructure

	attr_reader :finalhash, :client

	def initialize(username,password,target, port = 1433, domain = nil, database = nil, verbose = false)

	#attr_reader :finalhash

	@username = username
	@password = password
	@target = target
	@port = port
	@domain = domain
	@database = database
	@verbose = verbose
	@masterdbs = []
	@finalhash = {}
	@client = nil

	end

	def pingHost
		begin
		live = Net::Ping::TCP.new(@target,@port,1)
			if live.ping?
				print "Server connection successful to #{@target}:#{@port}\n".yellow
			else
				puts "Server connection failed to #{@target}:#{@port}".red ; abort()
			end
		rescue
			puts "There was an issue with the network connection".red ; abort()
		end
	end


	def createClient
		begin
 		if @domain
 			@client = TinyTds::Client.new(:username => @domain + "\\" + @username,:password => @password, \
 			                             :host => @target, :port => @port, :login_timeout => 10, :timeout => 60)
 		else
 			@client = TinyTds::Client.new(:username => @username,:password => @password, :host => @target, \
 																	 :port => @port, :login_timeout => 10,:timeout => 60)
 		end
 		rescue
 		puts "Connection to the database failed. Please check your syntax and credentials.".red ; abort()
 		end

 		#Confirm server connection
		if @client.active?
		 	puts "Database connection successful with #{@username}/#{@password}".yellow
		else
		 	puts "There were connection problems, check your settings.".red ; abort()
		end

 	end


 	def queryDbsVersion
 		begin
	 		result = @client.execute("SELECT @@VERSION")
			if result.each[0][""].include?("2000")
				puts "Banner: Microsoft SQL Server 2000".yellow
			elsif result.each[0][""].include?("Server 2005")
				puts "Banner: Microsoft SQL Server 2005".yellow
			elsif result.each[0][""].include?("Server 2008")
				puts "Banner: Microsoft SQL Server 2008".yellow
			elsif result.each[0][""].include?("Server 2012")
				puts "Banner: Microsoft SQL Server 2012".yellow
			else
				puts "Unknown Version"
			end
		rescue
			puts "There was an issue enumerating the database version.".red
		end
	end


	def queryMasterDbs

		#If the user selects a specific target database
		if @database
 			@masterdbs = [@database]
 			@finalhash[@database] = {}
 			puts "Targeting '#{@database}' database specifically".yellow

 		else

 			#Enumerate the non-default databases
		 	begin
			 	result = @client.execute("SELECT name FROM master.dbo.sysdatabases") ; result.each
			 	count = 0
			 	while count < result.count do
			 		@masterdbs.push(result.each[count]["name"])
			 		count += 1
			 	end
			 	@masterdbs.delete("master") ; @masterdbs.delete("tempdb") ; @masterdbs.delete("model") ; @masterdbs.delete("msdb")
			 	puts "Enumerated #{@masterdbs.count.to_s} non-default databases.".yellow
			 	puts "Found: #{@masterdbs.join(", ")}".yellow

			 	#Cycle each master database, add each master db as a key to finalhash with tables as values
			 	@masterdbs.each do |mds| 
			 		@finalhash[mds] = {} 
			 	end

		 	rescue
		 		result.each
		 		puts "Warning! Unable to enumerate master databases!".red ; abort()
		 	end
		end
	end


	def queryDbsConnections
		@masterdbs.each do |mds|

		 	begin
		 	result = @client.execute("SELECT DISTINCT TABLE_SCHEMA FROM [" + mds.to_s + "].INFORMATION_SCHEMA.TABLES")
		 	result.each
		 	puts "Access to '#{mds}' confirmed.".yellow if @verbose

		 	rescue
		 	result.each
		 	puts "Could not access the '#{mds}' database. Could be lack of privileges.".red
		 	@masterdbs.delete(mds)
			 	if @masterdbs.length < 1
			 		puts "There are no more valid databases to access.".red ; abort()
			 	end
		 	end
		end
 	end

 	def BuildDatabaseHash

 		@masterdbs.each do |mds|

 			@schemalist = []

			#Extract the schemas
			begin
				result = @client.execute("SELECT DISTINCT TABLE_SCHEMA FROM #{mds}.INFORMATION_SCHEMA.TABLES")
				puts "Successfully enumerated #{mds} database schema".yellow if @verbose
	 			count = 0
	 			while count < result.each.count do
			 		@schemalist.push(result.each[count]["TABLE_SCHEMA"])
			 		count += 1
		 		end

		 	rescue
		 		puts "There was an issue enumerating the #{mds} database schema".red
		 	end

			@schemalist.each do |schema|
	
	 			#Enumerate tables names
				begin
					result = @client.execute("SELECT TABLE_NAME FROM #{mds}.INFORMATION_SCHEMA.TABLES WHERE TABLE_SCHEMA='#{schema}';")
					puts "Successfully enumerated tables from #{mds} > #{schema}".yellow if @verbose
		
				rescue
	 				puts "Issues enumerating tables from the #{mds} database. Could be lack of privileges.".red
	 				@schemalist.delete(schema)
	 				if @schemalist.length < 1
				 		puts "There are no more valid schemas to access".red
				 	end
	 			end

	 			#Add schemas to final hash

	 			@finalhash[mds][schema] = {}

	 			#Add schemas to final hash
				currenttablelist = []
				count = 0
	 			while count < result.each.count do
					currenttablelist.push(result.each[count]["TABLE_NAME"])
	 				count += 1
	 			end

	 			currenttablelist.each do |table|
	 				@finalhash[mds][schema][table] = {}
	 			end



	 			#Extract column names from the database
	 			currenttablelist.each do |table|

	 			columnlist = []

	 			begin
		 			result = @client.execute("SELECT COLUMN_NAME FROM #{mds}.INFORMATION_SCHEMA.COLUMNS WHERE TABLE_NAME = '#{table}' AND TABLE_SCHEMA='#{schema}'")
		 			puts "Successfully enumerated columns from #{mds} > #{schema} > #{table}".yellow if @verbose
		 			result.each
	 			rescue
	 				result.each
	 				puts "Issues enumerating columns from the #{table} table on the #{mds} database. Could be lack of privileges.".red
	 				currenttablelist.delete(table)
	 			end

	 			#Extract column names from the tiny_tds object and insert them as values to the table keys in the final hash
	 			count = 0
	 			while count < result.each.count do
	 				columnlist.push(result.each[count]["COLUMN_NAME"])
	 				count += 1
	 				result.each
	 			end	

	 			@finalhash[mds][schema][table] = columnlist

	 			end
			end
		end
	end
end



class KeywordSearch

	attr_reader :table_matches, :column_matches

	def initialize(dbs_structure, keyword = nil, rowcount = 0, port = 1433, domain = nil,truncate = 64,username,password,target,verbose,sample,depth,statistics)
			puts "#{@username} #{@password} #{@domain} #{@target} #{@port}"


		@finalhash = dbs_structure
		@masterdbs = readMasterdbs
		@keyword = keyword
		@keywords = readKeywords
		@rowcount = rowcount
		@verbose = verbose
		@sample = sample
		@depth = depth
		@truncate = truncate
		@statistics = statistics

		#Authentication
		@username = username
		@password = password
		@target = target
		@port = port
		@domain = domain

		#Create the database client connection
		createClient

	end

	def readMasterdbs
		return @finalhash.keys
	end

	def readKeywords
		if @keyword
 			keywords = []
 			keywords.push(@keyword)
		else
 			keywords = []
 			keywordfile = File.open("keywords.txt", "r")
 			keywordfile.each do |keyword|
 			keywords.push(keyword.to_s.gsub("\n",""))
 			end
 		end
 		return keywords
 	end

 	def createClient
		begin
  		if @domain
  			@client = TinyTds::Client.new(:username => @domain + "\\" + @username,:password => @password, \
  			                             :host => @target, :port => @port, :login_timeout => 10, :timeout => 60)
  		else
  			@client = TinyTds::Client.new(:username => @username,:password => @password, :host => @target, \
  																	 :port => @port, :login_timeout => 10, :timeout => 60)
  		end
		rescue
	 		puts "Connection to the database failed. Please check your syntax and credentials.".red ; abort()
		end

  	#Confirm server connection
 		if @client.active? == false
	 	 	puts "There were connection problems, check your settings.".red ; abort()
 		end
 	end


 	def searchHash

 	@table_matches = []
 	@column_matches = []

 	#5 loops to iterate through the database hash
	 	@masterdbs.each do |mds|	
	 		@keywords.each do |keyword|
	 			@finalhash[mds].each do |schema, table|
	 				table.each do |tablename, column|

	 					if tablename.to_s.match(/#{keyword}/i)

			 				#Check Row Count
			 				begin
								@client.execute("SET ANSI_NULLS, QUOTED_IDENTIFIER, CONCAT_NULL_YIELDS_NULL, ANSI_WARNINGS, ANSI_PADDING ON;")
			 					result = @client.execute("SELECT COUNT(*) FROM [#{mds}].[#{schema}].[#{tablename}]")
							rescue
								puts "Unable to connect to " + tablename.to_s
							end

							rowcount = 1

			 				if (result.each[0][""]) > @rowcount	
								rowcount = (result.each[0][""]).to_i

								#Table match found
								if keyword.to_s.include?("card")
									table_matches.push("#{keyword},#{mds},#{schema},#{tablename},padcolumn,#{result.each[0][""].to_s}")
				 					puts "Match! '" + keyword.to_s.light_green.underline + "' | #{mds} > #{schema} > #{tablename} | ".yellow + "Rows:".yellow + result.each[0][""].to_s
				 				else
				 					table_matches.push("#{keyword},#{mds},#{schema},#{tablename},padcolumn,#{result.each[0][""].to_s}")
				 					puts "Match! '" + keyword.to_s.green + "' | #{mds} > #{schema} > #{tablename} | ".yellow + "Rows:".yellow + result.each[0][""].to_s
				 				end

				 				#Output sample if option selection
				 				if @sample
				 					outputSampleData(mds,schema,table,tablename,@depth,@truncate)
				 				end
			 				end

		 				end

	 					column.each do |item|

	 						if item.to_s.match(/#{keyword}/i)
	 							#Check Row Count
			 					begin
	 								@client.execute("SET ANSI_NULLS, QUOTED_IDENTIFIER, CONCAT_NULL_YIELDS_NULL, ANSI_WARNINGS, ANSI_PADDING ON;")
	 								result = @client.execute("SELECT COUNT([#{item}]) FROM [#{mds}].[#{schema}].[#{tablename}]")
		 						rescue
	 								puts "Unable to enumerate row count from #{item} column".red
		 						end
	 						
						
	 							begin
	 								if (result.each[0][""]) > @rowcount
		 								rowcount = (result.each[0][""]).to_i
										
										#Column match found
										if keyword.to_s.include?("card")
											column_matches.push("#{keyword},#{mds},#{schema},#{tablename},#{item},#{result.each[0][""].to_s}")
		 									puts "Match! '" + keyword.to_s.light_green.underline + "' | #{mds} > #{schema} > #{tablename} > #{item} | ".yellow + "Rows:".yellow + result.each[0][""].to_s
		 								else
		 									column_matches.push("#{keyword},#{mds},#{schema},#{tablename},#{item},#{result.each[0][""].to_s}")
		 									puts "Match! '" + keyword.to_s.green + "' | #{mds} > #{schema} > #{tablename} > #{item} | ".yellow + "Rows:".yellow + result.each[0][""].to_s
		 								end

		 								#Output sample if option selection
				 						if @sample
				 						outputSampleData(mds,schema,table,tablename,@depth,@truncate)
				 						end

	 								end
	 							rescue
	 								puts "Unable to access #{mds} > #{schema} > #{tablename} > #{item}".red	if @verbose
	 							end
	 						end
	 					end
	 				end
	 			end
	 		end
	 	end

	 	if @statistics
			stats = PrintStatistics.new(@table_matches,@column_matches,@statistics)
			stats.gatherstats
	 	end

 	end




 	def outputSampleData(mds,schema,table,tablename,depth,truncate)

 	
 		@depth = depth
 		@truncate = truncate
 		@mds = mds
 		@schema = schema
 		@table = table
 		@tablename = tablename

 		outputtable = Text::Table.new

 		begin
 		result = @client.execute("SELECT TOP 10 * FROM [#{mds}].[#{schema}].[#{tablename}]")
 		rescue
 			puts "There was an issue selecting the row count, could be database configuraion issues.".red if @verbose
 		end

 		userdepth = @depth
 		maxdepth = result.each.count

 		outputtable.head = table[tablename]

 		count = 0						
		while (count < userdepth) && (count < maxdepth)

			#Truncate large data values
			tempvalues = result.each[count].values
	 		tempvalues.map! { |value|
				if(value.to_s.length > @truncate)
	 				"TRUNCATED"
		 		else
		 			value
	 			end
	 			}
	 		#Correct NULL values
	 			tempvalues.map! { |value|
				if(value == nil)
	 				"NULL VALUE"
		 		else
		 			value
	 			end
	 			}


	 		outputtable.rows << tempvalues
		 	count += 1
	 	end
	 begin
  	puts outputtable.to_s
  	rescue
  		puts "There were issues outputting the sample data, could be odd characters".red if @verbose
  	end
 	end
end

class CreateFileOutput

	def initialize(table_matches,column_matches,filename)
		@table_matches = table_matches
		@column_matches = column_matches
		@filename = filename

		File.open(@filename,'w') do |file|
 		file.write("KEYWORD,DATABASE,SCHEMA,TABLE,COLUMN,ROWCOUNT\n")
 		file.close
		end
	end

	def createFile
		begin
 		File.open(@filename,'a') do |file|
 			@table_matches.each do |entry|
 				file.write("#{entry}\n")
 				end
 			@column_matches.each do |entry|
 				file.write("#{entry}\n")
 				end
 		end
 		rescue
 			puts "There was a problem creating the output file".red
 		end
 	end
end


class PrintStatistics

	def initialize(table_matches,column_matches,statistics)
		@table_matches = table_matches
		@column_matches = column_matches
		@statistics = statistics
	end

	def gatherstats
		puts "\nBasic Statistics\n"
		print puts "Table matches found:".yellow + @table_matches.length.to_s
		print puts "Column matches found:".yellow + @column_matches.length.to_s


		all_matches = @table_matches + @column_matches
		count = Hash.new 0
		all_matches.each do |match|
		 count[match.split(",")[3]] += 1
		end


		puts "\nTop 10 Matched Tables\n"

		sorted_count = count.sort_by { |k,v| v}.reverse

		count = 0
		sorted_count.each do |key,value|
		 count += 1
		 puts "#{key}:".yellow + "#{value}"
			 if count == 10
			 	break
			 end
		end

		puts "\nTop 10 Keywords\n"
		keyword_count = Hash.new 0
		all_matches.each do |match|
		 keyword_count[match.split(",")[0]] += 1
		end

		sorted_keyword_count = keyword_count.sort_by { |k,v| v}.reverse

		count = 0
		sorted_keyword_count.each do |key,value|
		 count += 1
		 puts "#{key}:".yellow + "#{value}"
		 	if count == 10
		 	 break
		 	end
		end

		puts "\nTop 10 Row Counts\n"

		row_count = Hash.new
		all_matches.each do |match|
		 row_count[match.split(",")[3]] = match.split(",")[5].to_i
		end

		sorted_row_count = row_count.sort_by { |k,v| v}.reverse

		count = 0
		sorted_row_count.each do |key,value|
		 count += 1
		 puts "#{key}:".yellow + value.to_s
		 	if count == 10
		 	 break
		 	end
		end


		puts "\nTop 10 Databases with Matches\n"

		db_count = Hash.new 0
		all_matches.each do |match|
		 db_count[match.split(",")[1]] += 1
		end

		sorted_db_count = db_count.sort_by { |k,v| v}.reverse

		count = 0
		sorted_db_count.each do |key,value|
		 count += 1
		 puts "#{key}:".yellow + value.to_s
		 	if count == 10
		 	 break
		 	end
		end

		puts ""

	end

end





#Object control - Main program



enumdb = EnumerateDatabaseStructure.new(opts[:username],\
																				opts[:password],\
																				opts[:target],\
																			  opts[:port],\
																			  opts[:domain],\
																			  opts[:database],\
																			  opts[:verbose],)
enumdb.pingHost
enumdb.createClient
enumdb.queryDbsVersion
enumdb.queryMasterDbs
enumdb.queryDbsConnections
enumdb.BuildDatabaseHash


search = KeywordSearch.new(enumdb.finalhash,\
 												   opts[:keyword],\
 													 opts[:rowcount],\
 													 opts[:port],\
 													 opts[:domain],\
 													 opts[:truncate],\
 													 opts[:username],\
 												   opts[:password],\
 												   opts[:target],\
 												   opts[:verbose],\
 												   opts[:sample],\
 												   opts[:depth],\
 												   opts[:statistics])



search.searchHash


if opts[:export]
	fileoutput = CreateFileOutput.new(search.table_matches,search.column_matches,opts[:export])
	fileoutput.createFile
end





