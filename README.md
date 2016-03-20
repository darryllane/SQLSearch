# SQLSearch v2.1.0

What dependencies are there?

gem install tiny_tds, gem install colorize, gem install trollop

What does the tool do?

SQLSearch is a tool intended for penetration testers, helping them to locate potentially sensitive information is large Microsoft SQL databases. Connecting with either Sa or Windows authentication, the script will enumerate all table/column names and compare them with a list of keywords. Additionally, a small sample of 10 rows of data can be outputed to confirm if an issue exists. Blank tables will not be included in the output. This tool is not intended to be used to navigate SQL databases, just simply to locate starting points where sensitive data may exist.

How do I use it?

You can issue 'ruby sqlsearch.rb --help' for a list of commands. However, the most basic connection syntax would be:

DATABASE AUTHENTICATION
$ruby sqlsearch.rb -u sa -p password -t 10.0.0.1

WINDOWS AUTHENTICATION
$ruby sqlsearch.rb -w -u administrator -p password -d WORKGROUP -t 10.0.0.1
