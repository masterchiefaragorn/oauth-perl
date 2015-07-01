# oauth-perl
A Perl script for establishing an OAuth connection to Intuit's QuickBooks Online and making a QBO API call
by Eric Simon, a developer for Vertical Approach, LLC.

This script will require these two Perl modules which may not be in your distribution of Perl:

JSON::Parse
------------------------------------------------------------------------------------------------------
To install the JSON::Parse module, download it from:

	https://metacpan.org/pod/distribution/JSON-Parse/lib/JSON/Parse.pod

After downloading it, you will need to unzip it, and install it.  In Linux, this is what I do:

	tar -xzf JSON-Parse-*
	cd JSON-Parse-*
	perl Makefile.PL
	make install
	cd ..
	rm -rf JSON-Parse-*

Data::UUID
------------------------------------------------------------------------------------------------------
To install the Data::UUID module, download it from:

	https://metacpan.org/pod/Data::UUID

After downloading it, you will need to unzip it, and install it.  In Linux, this is what I do:

	tar -xzf Data-UUID-*
	cd Data-UUID-*
	perl Makefile.PL
	make install
	cd ..
	rm -rf Data-UUID-*
