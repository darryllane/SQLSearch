# SQLSearch v3.0.0

##Description
SQLSearch is a tool intended for penetration testers, helping them to locate potentially sensitive information is large Microsoft SQL databases. Connecting with either Sa or Windows authentication, the script will enumerate all table/column names and compare them with a list of keywords. Additionally, a small sample of 10 rows of data can be outputed to confirm if an issue exists. Blank tables will not be included in the output. This tool is not intended to be used to navigate SQL databases, just simply to locate starting points where sensitive data may exist.

##Kali Installation

```
sudo bundle install
```

##OSX Installation
The FreeTDS drivers are necessary to run sqlsearch on osx. These can be installed easily using HomeBrew.

```
$ brew install unixodbc
$ brew install freetds --with-unixodbc
```

##Usage Example
You can issue './sqlsearch.rb --help' for a list of commands. However, the most basic connection syntax would be:

```
$./sqlsearch.rb -u sa -p password -t 10.0.0.1

$./sqlsearch.rb -u administrator -p password -d WORKGROUP -t 10.0.0.1
```

##Specifying custom regex
When using the --keyword(-k) option you can submit regular expressions. However, it is neccesary to escape any special characters. For example, the syntax to find any tables or column names that contain 1 to 4 characters:

```
-k \^.\{1,5\}\$
```

Or to find all table and column names ending in 'ing'

```
-k ing\$
```

##Truncate
The default behavoir is to truncate any cell data that exceeds 64 characters in length. This is to prevent data such as image file from being displayed in the terminal as sample date. This setting can be overridden with the --truncate(-t) option.


##Tool Options

```
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
```






