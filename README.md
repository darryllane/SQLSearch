What dependencies are there?

gem install tiny_tds gem install colorize gem install trollop gem install text-table


SQLSearch is a tool intended for penetration testers, helping them to locate potentially sensitive information is large Microsoft SQL databases. Connecting with either Sa or Windows authentication, the script will enumerate all table/column names and compare them with a list of keywords. Additionally, a small sample of 10 rows of data can be outputed to confirm if an issue exists. Blank tables will not be included in the output. This tool is not intended to be used to navigate SQL databases, just simply to locate starting points where sensitive data may exist.

You can issue 'ruby sqlsearch.rb --help' for a list of commands. However, the most basic connection syntax would be:

DATABASE AUTHENTICATION $ruby sqlsearch.rb -u sa -p password -t 10.0.0.1

<<<<<<< HEAD
WINDOWS AUTHENTICATION $ruby sqlsearch.rb -u administrator -p password -d WORKGROUP -t 10.0.0.1
=======
$ruby sqlsearch.rb -w -u administrator -p Pa55w0rd -d WORKGROUP -t 10.0.0.1 -o output.txt
   
-u, --username=<s>    SA/Windows Username
-p, --password=<s>    SA/Windows Password
  -d, --domain=<s>      Windows Domain Name
  -t, --target=<s>      Target Server IP Address/Hostname
  -a, --database=<s>    Target a Single Database
  -o, --port=<i>        Target Port (default: 1433)
  -k, --keyword=<s>     Specify Specific Keyword (Ignores keywords.txt)
  -s, --sample          Output Sample Data from Matches
  -e, --depth=<i>       Sample Data Depth. Max: 10 (default: 1)
  -r, --truncate=<i>    Truncate Sample Data (default: 64)
  -w, --rowcount=<i>    Minimum Row Count (default: 1)
  -q, --query           Show Example SQL Queries
  -h, --hide            Hide Warning Messages
  -x, --export=<s>      Output Matches to CSV File
  -v, --version         Print version and exit
  -l, --help            Show this message
>>>>>>> 35d6e39c01c1f56eb24604bd096b134ae215a9b7
