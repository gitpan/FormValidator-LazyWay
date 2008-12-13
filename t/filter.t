use Test::Base;
use FormValidator::LazyWay::Filter;
use Data::Dumper;
use utf8;

plan tests => 1 * blocks;

run {
    my $block  = shift;
    my $filter = FormValidator::LazyWay::Filter->new( config => $block->config );

    is( $filter->setting->{strict}{hoge}[0]{label}  , $block->setting );
    
}

__END__
=== normal
--- config yaml
filters :
    - Encode
setting :
    strict :
        hoge :
            filter :
                - Encode::decode
--- setting chomp
Encode::decode
