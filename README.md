# SQLSearch v2.4.1

What dependencies are there?

gem install tiny_tds
gem install colorize
gem install trollop
gem install text-table

SQLSearch v1.0
A tool used to help security consultants locate potentially
sensitive information in Microsoft SQL databases. The table and
column names are extracted from the database and are compared with
a list of keywords using regex.

Example Usage:

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
