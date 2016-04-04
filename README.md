# SQLSearch v3.0.0

## Installation

sudo bundle install

## Description

SQLSearch is a tool intended for penetration testers, helping them to locate potentially sensitive information is large Microsoft SQL databases. Connecting with either Sa or Windows authentication, the script will enumerate all table/column names and compare them with a list of keywords. Additionally, a small sample of 10 rows of data can be outputed to confirm if an issue exists. Blank tables will not be included in the output. This tool is not intended to be used to navigate SQL databases, just simply to locate starting points where sensitive data may exist.

##Usage Example

You can issue './sqlsearch.rb --help' for a list of commands. However, the most basic connection syntax would be:

$./sqlsearch.rb -u sa -p password -t 10.0.0.1

$./sqlsearch.rb -u administrator -p password -d WORKGROUP -t 10.0.0.1

##Options

-u --username    Specify the database/Windows username
-p --password    Specify the database/Windows password
-d --domain      Specify the Windows domain
-t --target      Specify the target host (IP address / hostname)
-a --database    Target a single database (Does not enumerate)
-o --port        Specify a non-default port (Default is 1433)
-k --keyword     Specify a specific keyword to use (Ignore keywords.txt)
-s --sample      Output a row from each database table that matched a keyword
-e --depth       Specify the amount of rows to output when using -s (Default is 1)
-r --truncate    Truncate Sample Data (default: 64)
-w --rowcount    Specify the minimum Row Count (Default is 1)
-v --verbose     Show Verbose Output
-x --export      Output Matches to CSV File
