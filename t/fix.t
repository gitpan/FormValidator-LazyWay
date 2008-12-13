use Test::Base;
use FormValidator::LazyWay::Fix;
use Data::Dumper;
use utf8;

plan tests => 1 * blocks;

run {
    my $block  = shift;
    my $filter = FormValidator::LazyWay::Fix->new( config => $block->config );

    is( $filter->setting->{strict}{hoge}[0]{label}  , $block->setting );
}

__END__
=== normal
--- config yaml
fixes:
  - DateTime
setting :
  strict :
    hoge :
      fix :
        - DateTime#format:
            - '%Y-%m-%d %H:%M:%S'
--- setting chomp
DateTime#format

