# SQLSearch v3.2.3

##Description
SQLSearch is a tool intended for penetration testers, helping them to locate potentially sensitive information is large Microsoft SQL databases. Connecting with either Sa or Windows authentication, the script will enumerate all table/column names and compare them with a list of keywords. Additionally, a small sample of 10 rows of data can be outputted to confirm if an issue exists. Blank tables will not be included in the output. This tool is not intended to be used to navigate SQL databases, just simply to locate starting points where sensitive data may exist.

##Kali Installation

```
sudo bundle install
```

##OSX Installation
TBC...


##Usage Example
You can issue './sqlsearch.rb --help' for a list of commands. However, the most basic connection syntax would be:

```
$./sqlsearch.rb -u sa -p password -t 10.0.0.1

$./sqlsearch.rb -u administrator -p password -d WORKGROUP -t 10.0.0.1
```

##Example Output
The following output was from running sqlsearch against a Microsoft SQL Server 2008 with the Northwind sample database installed.

```
kali% ./sqlsearch.rb -u administrator -p Password1 -d WORKGROUP -t 10.1.1.1 -a Northwind

Server connection successful to 10.1.1.1:1433
Database connection successful with administrator/Password1
Banner: Microsoft SQL Server 2008
Targeting 'Northwind' database specifically
    
Match! 'amount' | Northwind > dbo > Sales Totals by Amount | Rows:66
Match! 'amount' | Northwind > dbo > Sales Totals by Amount > SaleAmount | Rows:66
Match! 'birth' | Northwind > dbo > Employees > BirthDate | Rows:9
Match! 'code' | Northwind > dbo > Orders > ShipPostalCode | Rows:811
Match! 'code' | Northwind > dbo > Orders Qry > ShipPostalCode | Rows:811
Match! 'code' | Northwind > dbo > Orders Qry > PostalCode | Rows:811
Match! 'code' | Northwind > dbo > Invoices > ShipPostalCode | Rows:2100
Match! 'code' | Northwind > dbo > Invoices > PostalCode | Rows:2100
Match! 'code' | Northwind > dbo > Employees > PostalCode | Rows:9
Match! 'code' | Northwind > dbo > Customers > PostalCode | Rows:90
Match! 'code' | Northwind > dbo > Suppliers > PostalCode | Rows:29
Match! 'customer' | Northwind > dbo > Orders > CustomerID | Rows:830
Match! 'customer' | Northwind > dbo > Customer and Suppliers by City | Rows:120
Match! 'customer' | Northwind > dbo > Orders Qry > CustomerID | Rows:830
Match! 'customer' | Northwind > dbo > Quarterly Orders > CustomerID | Rows:86
Match! 'customer' | Northwind > dbo > Invoices > CustomerID | Rows:2155
Match! 'customer' | Northwind > dbo > Invoices > CustomerName | Rows:2155
Match! 'customer' | Northwind > dbo > Customers | Rows:91
Match! 'customer' | Northwind > dbo > Customers > CustomerID | Rows:91
Match! 'employee' | Northwind > dbo > Orders > EmployeeID | Rows:830
Match! 'employee' | Northwind > dbo > Orders Qry > EmployeeID | Rows:830
Match! 'employee' | Northwind > dbo > EmployeeTerritories | Rows:49
Match! 'employee' | Northwind > dbo > EmployeeTerritories > EmployeeID | Rows:49
Match! 'employee' | Northwind > dbo > Employees | Rows:9
Match! 'employee' | Northwind > dbo > Employees > EmployeeID | Rows:9
```

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
-i --statistics  Show Statistics  
-x --export      Output Matches to CSV File  
```

##Custom Regex
When using the --keyword(-k) option you can submit regular expressions. However, it is necessary to escape any special characters. For example, the syntax to find any tables or column names that contain 1 to 4 characters would be:

```
-k \^.\{1,5\}\$
```

...or to find all table and column names ending in 'ing' would be:

```
-k ing\$
```

##Truncate
The default behavior is to truncate any cell data that exceeds 64 characters in length. This is to prevent data such as image files from being displayed in the terminal as sample data. This setting can be overridden with the --truncate(-t) option.

