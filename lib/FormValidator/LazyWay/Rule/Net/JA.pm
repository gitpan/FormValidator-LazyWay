package FormValidator::LazyWay::Rule::Net::JA;

use strict;
use warnings;
use utf8;

sub uri { 'http:// ftp://などのuri' }
sub url { 'http://又は、https://から始まるurl' }
sub http { 'http://からはじまるurl' }
sub https { 'https://からはじまるurl' }
sub url_loose { 'http://又は、https://から始まるurl' }
sub http_loose { 'http://からはじまるurl' }
sub https_loose { 'https://からはじまるurl' }

1;
